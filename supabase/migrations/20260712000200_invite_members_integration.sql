-- Homeventory Supabase integration follow-ups
-- - Accept invitations by short code as well as raw token
-- - Soft-remove / leave membership RPCs
-- - Fellow-member profile visibility within a shared Home

-- ---------------------------------------------------------------------------
-- accept_invitation: token (>=32 chars) or short code
-- ---------------------------------------------------------------------------

create or replace function public.accept_invitation(p_token text)
returns public.home_members
language plpgsql
security definer
set search_path = public
as $$
declare
  invite public.invitations%rowtype;
  member public.home_members%rowtype;
  token_digest text;
  input text;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  input := trim(p_token);
  if input is null or length(input) = 0 then
    raise exception 'invitation token or code is required';
  end if;

  if length(input) >= 32 then
    token_digest := encode(digest(input, 'sha256'), 'hex');
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
    role = excluded.role,
    status = 'ACTIVE',
    joined_at = coalesce(public.home_members.joined_at, excluded.joined_at),
    removed_at = null,
    invited_by_user_id = excluded.invited_by_user_id,
    updated_at = timezone('utc', now())
  returning * into member;

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

-- ---------------------------------------------------------------------------
-- remove_home_member: OWNER/ADMIN soft-removes another member
-- ---------------------------------------------------------------------------

create or replace function public.remove_home_member(
  p_home_id uuid,
  p_user_id uuid
)
returns public.home_members
language plpgsql
security definer
set search_path = public
as $$
declare
  target public.home_members%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;
  if not public.can_manage_members(p_home_id) then
    raise exception 'not authorized to remove members';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'use leave_home to leave a home yourself';
  end if;

  select * into target
  from public.home_members
  where home_id = p_home_id
    and user_id = p_user_id
  for update;

  if target.id is null then
    raise exception 'membership not found';
  end if;
  if target.role = 'OWNER' then
    raise exception 'cannot remove the home OWNER';
  end if;
  if target.status = 'REMOVED' then
    return target;
  end if;

  update public.home_members
  set
    status = 'REMOVED',
    removed_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  where id = target.id
  returning * into target;

  return target;
end;
$$;

revoke all on function public.remove_home_member(uuid, uuid) from public;
grant execute on function public.remove_home_member(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- leave_home: active non-owner leaves voluntarily
-- ---------------------------------------------------------------------------

create or replace function public.leave_home(p_home_id uuid)
returns public.home_members
language plpgsql
security definer
set search_path = public
as $$
declare
  target public.home_members%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  select * into target
  from public.home_members
  where home_id = p_home_id
    and user_id = auth.uid()
  for update;

  if target.id is null then
    raise exception 'membership not found';
  end if;
  if target.role = 'OWNER' then
    raise exception 'OWNER cannot leave; transfer ownership or archive the home';
  end if;
  if target.status in ('REMOVED', 'LEFT') then
    return target;
  end if;

  update public.home_members
  set
    status = 'LEFT',
    removed_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  where id = target.id
  returning * into target;

  return target;
end;
$$;

revoke all on function public.leave_home(uuid) from public;
grant execute on function public.leave_home(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Profiles: members can view fellow active members' profiles in shared Homes
-- ---------------------------------------------------------------------------

drop policy if exists profiles_select_fellow_members on public.profiles;

create policy profiles_select_fellow_members
on public.profiles for select
to authenticated
using (
  exists (
    select 1
    from public.home_members mine
    inner join public.home_members theirs
      on theirs.home_id = mine.home_id
    where mine.user_id = auth.uid()
      and mine.status = 'ACTIVE'
      and mine.removed_at is null
      and theirs.user_id = profiles.id
      and theirs.status = 'ACTIVE'
      and theirs.removed_at is null
  )
);
