-- Fix invite create/accept: pgcrypto digest(text, unknown) fails on hosted
-- Postgres (needs bytea + explicit algorithm type; extension lives in
-- `extensions` on Supabase). Include extensions in search_path and hash via
-- convert_to(...).

create or replace function public.create_invitation(
  p_home_id uuid,
  p_role public.home_role,
  p_token text,
  p_short_code text default null,
  p_invited_email text default null,
  p_expires_in_hours integer default 72
)
returns public.invitations
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  invite public.invitations%rowtype;
begin
  if not public.can_manage_members(p_home_id) then
    raise exception 'not authorized to invite members';
  end if;
  if p_role = 'OWNER' then
    raise exception 'cannot invite as OWNER; transfer ownership instead';
  end if;
  if p_token is null or length(p_token) < 32 then
    raise exception 'token must be at least 32 characters';
  end if;

  insert into public.invitations (
    home_id,
    role,
    token_hash,
    short_code,
    invited_email,
    created_by_user_id,
    expires_at
  ) values (
    p_home_id,
    p_role,
    encode(digest(convert_to(p_token, 'UTF8'), 'sha256'), 'hex'),
    p_short_code,
    p_invited_email,
    auth.uid(),
    timezone('utc', now()) + make_interval(hours => p_expires_in_hours)
  )
  returning * into invite;

  return invite;
end;
$$;

revoke all on function public.create_invitation(uuid, public.home_role, text, text, text, integer) from public;
grant execute on function public.create_invitation(uuid, public.home_role, text, text, text, integer) to authenticated;

create or replace function public.accept_invitation(p_token text)
returns public.home_members
language plpgsql
security definer
set search_path = public, extensions
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
