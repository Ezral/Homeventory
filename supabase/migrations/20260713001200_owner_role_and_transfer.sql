-- Owner can change member roles (ADMIN/EDITOR/VIEWER) and transfer ownership.
-- Transfer demotes the current owner to ADMIN and promotes the target to OWNER.

create or replace function public.set_home_member_role(
  p_home_id uuid,
  p_user_id uuid,
  p_role public.home_role
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
  if not public.can_admin_home(p_home_id) then
    raise exception 'only the home OWNER can change member roles';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'cannot change your own role; transfer ownership instead';
  end if;
  if p_role = 'OWNER' then
    raise exception 'use transfer_home_ownership to grant OWNER';
  end if;
  if p_role not in ('ADMIN', 'EDITOR', 'VIEWER') then
    raise exception 'invalid role';
  end if;

  select * into target
  from public.home_members
  where home_id = p_home_id
    and user_id = p_user_id
  for update;

  if target.id is null then
    raise exception 'membership not found';
  end if;
  if target.status <> 'ACTIVE' then
    raise exception 'membership is not active';
  end if;
  if target.role = 'OWNER' then
    raise exception 'cannot change the OWNER role; transfer ownership instead';
  end if;

  if target.role = p_role then
    return target;
  end if;

  update public.home_members
  set
    role = p_role,
    updated_at = timezone('utc', now())
  where id = target.id
  returning * into target;

  return target;
end;
$$;

revoke all on function public.set_home_member_role(uuid, uuid, public.home_role) from public;
grant execute on function public.set_home_member_role(uuid, uuid, public.home_role) to authenticated;

create or replace function public.transfer_home_ownership(
  p_home_id uuid,
  p_new_owner_user_id uuid
)
returns public.home_members
language plpgsql
security definer
set search_path = public
as $$
declare
  current_owner public.home_members%rowtype;
  new_owner public.home_members%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;
  if not public.can_admin_home(p_home_id) then
    raise exception 'only the home OWNER can transfer ownership';
  end if;
  if p_new_owner_user_id = auth.uid() then
    raise exception 'already the home OWNER';
  end if;

  select * into current_owner
  from public.home_members
  where home_id = p_home_id
    and user_id = auth.uid()
  for update;

  if current_owner.id is null or current_owner.status <> 'ACTIVE' then
    raise exception 'OWNER membership not found';
  end if;
  if current_owner.role <> 'OWNER' then
    raise exception 'only the home OWNER can transfer ownership';
  end if;

  select * into new_owner
  from public.home_members
  where home_id = p_home_id
    and user_id = p_new_owner_user_id
  for update;

  if new_owner.id is null then
    raise exception 'new OWNER must already be a member of this home';
  end if;
  if new_owner.status <> 'ACTIVE' then
    raise exception 'new OWNER membership is not active';
  end if;

  -- Demote current owner first so there is never a second OWNER row briefly
  -- conflicting with product assumptions; then promote the target.
  update public.home_members
  set
    role = 'ADMIN',
    updated_at = timezone('utc', now())
  where id = current_owner.id;

  update public.home_members
  set
    role = 'OWNER',
    updated_at = timezone('utc', now())
  where id = new_owner.id
  returning * into new_owner;

  return new_owner;
end;
$$;

revoke all on function public.transfer_home_ownership(uuid, uuid) from public;
grant execute on function public.transfer_home_ownership(uuid, uuid) to authenticated;
