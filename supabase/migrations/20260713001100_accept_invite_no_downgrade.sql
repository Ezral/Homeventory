-- Fix: accepting an invite must never demote an existing member.
-- Owners who open their own viewer invite were getting role = VIEWER.
-- Also repair creators who were demoted, and do not burn an invite when the
-- acceptor already holds an equal or higher role.

create or replace function public.home_role_rank(p_role public.home_role)
returns integer
language sql
immutable
as $$
  select case p_role
    when 'OWNER' then 4
    when 'ADMIN' then 3
    when 'EDITOR' then 2
    when 'VIEWER' then 1
    else 0
  end;
$$;

revoke all on function public.home_role_rank(public.home_role) from public;
grant execute on function public.home_role_rank(public.home_role) to authenticated;

create or replace function public.accept_invitation(p_token text)
returns public.home_members
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  invite public.invitations%rowtype;
  member public.home_members%rowtype;
  existing public.home_members%rowtype;
  token_digest text;
  input text;
  next_role public.home_role;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  input := trim(p_token);
  if input is null or length(input) = 0 then
    raise exception 'invitation token or code is required';
  end if;

  if length(input) >= 32 then
    token_digest := encode(digest(convert_to(input, 'UTF8'), 'sha256'), 'hex');
    select * into invite
    from public.invitations
    where token_hash = token_digest
    for update;
  else
    select * into invite
    from public.invitations
    where upper(short_code) = upper(input)
    for update;
  end if;

  if invite.id is null then
    raise exception 'invitation not found';
  end if;
  if invite.status <> 'ACTIVE' then
    raise exception 'invitation is not active';
  end if;
  if invite.expires_at <= timezone('utc', now()) then
    update public.invitations
    set status = 'EXPIRED'
    where id = invite.id;
    raise exception 'invitation has expired';
  end if;
  if invite.invited_email is not null then
    if lower(invite.invited_email) <> lower(coalesce(auth.jwt() ->> 'email', '')) then
      raise exception 'invitation is restricted to another email';
    end if;
  end if;

  select * into existing
  from public.home_members
  where home_id = invite.home_id
    and user_id = auth.uid()
  for update;

  -- Already an active member at equal/higher privilege: keep role, keep invite usable.
  if existing.id is not null
     and existing.status = 'ACTIVE'
     and public.home_role_rank(existing.role) >= public.home_role_rank(invite.role)
  then
    return existing;
  end if;

  if existing.id is not null
     and existing.status = 'ACTIVE'
  then
    -- Upgrade only (invite role is strictly higher).
    next_role := invite.role;
    update public.home_members
    set
      role = next_role,
      invited_by_user_id = coalesce(invited_by_user_id, invite.created_by_user_id),
      updated_at = timezone('utc', now())
    where id = existing.id
    returning * into member;
  else
    insert into public.home_members (
      home_id,
      user_id,
      role,
      status,
      joined_at,
      invited_by_user_id
    ) values (
      invite.home_id,
      auth.uid(),
      invite.role,
      'ACTIVE',
      timezone('utc', now()),
      invite.created_by_user_id
    )
    on conflict (home_id, user_id) do update
    set
      -- Revive removed members; never assign a weaker role than they held.
      role = case
        when public.home_role_rank(public.home_members.role)
           >= public.home_role_rank(excluded.role)
        then public.home_members.role
        else excluded.role
      end,
      status = 'ACTIVE',
      joined_at = coalesce(public.home_members.joined_at, excluded.joined_at),
      removed_at = null,
      invited_by_user_id = coalesce(
        public.home_members.invited_by_user_id,
        excluded.invited_by_user_id
      ),
      updated_at = timezone('utc', now())
    returning * into member;
  end if;

  update public.invitations
  set
    status = 'ACCEPTED',
    accepted_by_user_id = auth.uid(),
    accepted_at = timezone('utc', now())
  where id = invite.id;

  return member;
end;
$$;

revoke all on function public.accept_invitation(text) from public;
grant execute on function public.accept_invitation(text) to authenticated;

-- Repair home creators who were demoted by accepting their own invite link.
update public.home_members hm
set
  role = 'OWNER',
  updated_at = timezone('utc', now())
from public.homes h
where hm.home_id = h.id
  and hm.user_id = h.created_by_user_id
  and hm.status = 'ACTIVE'
  and hm.role <> 'OWNER';
