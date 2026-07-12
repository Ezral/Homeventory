-- Homeventory Phase 1–3 foundation
-- Profiles, Homes, membership, invitations, rooms, inventory nodes, RLS helpers.
-- Authorization rule: active membership in the Home that owns the record.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

create type public.home_role as enum ('OWNER', 'ADMIN', 'EDITOR', 'VIEWER');

create type public.membership_status as enum (
  'PENDING',
  'ACTIVE',
  'REMOVED',
  'LEFT'
);

create type public.invitation_status as enum (
  'ACTIVE',
  'ACCEPTED',
  'REVOKED',
  'EXPIRED'
);

create type public.inventory_node_kind as enum (
  'FURNITURE',
  'STORAGE_LOCATION',
  'ITEM'
);

create type public.item_category as enum (
  'EDIBLE',
  'CONSUMABLE',
  'CLOTHING',
  'BAG_LUGGAGE',
  'ELECTRONICS',
  'MISC'
);

-- ---------------------------------------------------------------------------
-- Utility: updated_at trigger
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Authorization helpers (security definer, stable)
-- Deny-by-default callers: policies must invoke these explicitly.
-- Implemented in plpgsql so CREATE FUNCTION does not require tables yet.
-- ---------------------------------------------------------------------------

create or replace function public.is_home_member(p_home_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return exists (
    select 1
    from public.home_members hm
    where hm.home_id = p_home_id
      and hm.user_id = auth.uid()
      and hm.status = 'ACTIVE'
      and hm.removed_at is null
  );
end;
$$;

create or replace function public.home_role_of(p_home_id uuid)
returns public.home_role
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  result public.home_role;
begin
  select hm.role
  into result
  from public.home_members hm
  where hm.home_id = p_home_id
    and hm.user_id = auth.uid()
    and hm.status = 'ACTIVE'
    and hm.removed_at is null
  limit 1;
  return result;
end;
$$;

create or replace function public.can_view_home(p_home_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return public.is_home_member(p_home_id);
end;
$$;

create or replace function public.can_edit_inventory(p_home_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return public.home_role_of(p_home_id) in ('OWNER', 'ADMIN', 'EDITOR');
end;
$$;

create or replace function public.can_manage_members(p_home_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return public.home_role_of(p_home_id) in ('OWNER', 'ADMIN');
end;
$$;

create or replace function public.can_admin_home(p_home_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return public.home_role_of(p_home_id) = 'OWNER';
end;
$$;

revoke all on function public.is_home_member(uuid) from public;
revoke all on function public.home_role_of(uuid) from public;
revoke all on function public.can_view_home(uuid) from public;
revoke all on function public.can_edit_inventory(uuid) from public;
revoke all on function public.can_manage_members(uuid) from public;
revoke all on function public.can_admin_home(uuid) from public;

grant execute on function public.is_home_member(uuid) to authenticated;
grant execute on function public.home_role_of(uuid) to authenticated;
grant execute on function public.can_view_home(uuid) to authenticated;
grant execute on function public.can_edit_inventory(uuid) to authenticated;
grant execute on function public.can_manage_members(uuid) to authenticated;
grant execute on function public.can_admin_home(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  display_name text,
  avatar_url text,
  preferred_currency text not null default 'USD',
  preferred_language text not null default 'en',
  timezone text not null default 'UTC',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name, avatar_url)
  values (
    new.id,
    new.email,
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      split_part(coalesce(new.email, 'user'), '@', 1)
    ),
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;

create policy profiles_select_own
on public.profiles for select
to authenticated
using (id = auth.uid());

create policy profiles_update_own
on public.profiles for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

-- Inserts come from the auth trigger (security definer), not clients.
create policy profiles_no_client_insert
on public.profiles for insert
to authenticated
with check (false);

-- ---------------------------------------------------------------------------
-- homes
-- ---------------------------------------------------------------------------

create table public.homes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  cover_image_id uuid,
  address_text text,
  timezone text not null default 'UTC',
  default_currency text not null default 'USD',
  created_by_user_id uuid not null references public.profiles (id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  archived_at timestamptz
);

create trigger homes_set_updated_at
before update on public.homes
for each row execute function public.set_updated_at();

alter table public.homes enable row level security;

create policy homes_select_member
on public.homes for select
to authenticated
using (public.can_view_home(id));

create policy homes_insert_authenticated
on public.homes for insert
to authenticated
with check (created_by_user_id = auth.uid());

create policy homes_update_owner
on public.homes for update
to authenticated
using (public.can_admin_home(id))
with check (public.can_admin_home(id));

create policy homes_delete_owner
on public.homes for delete
to authenticated
using (public.can_admin_home(id));

-- Creator becomes OWNER when a Home is created.
create or replace function public.handle_new_home()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.home_members (
    home_id,
    user_id,
    role,
    status,
    joined_at
  ) values (
    new.id,
    new.created_by_user_id,
    'OWNER',
    'ACTIVE',
    timezone('utc', now())
  );
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- home_members
-- ---------------------------------------------------------------------------

create table public.home_members (
  id uuid primary key default gen_random_uuid(),
  home_id uuid not null references public.homes (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role public.home_role not null,
  status public.membership_status not null default 'PENDING',
  joined_at timestamptz,
  invited_by_user_id uuid references public.profiles (id),
  removed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (home_id, user_id)
);

create index home_members_user_id_idx on public.home_members (user_id);
create index home_members_home_active_idx
  on public.home_members (home_id)
  where status = 'ACTIVE' and removed_at is null;

create trigger home_members_set_updated_at
before update on public.home_members
for each row execute function public.set_updated_at();

create trigger on_home_created
after insert on public.homes
for each row execute function public.handle_new_home();

alter table public.home_members enable row level security;

create policy home_members_select_same_home
on public.home_members for select
to authenticated
using (public.can_view_home(home_id));

create policy home_members_insert_manager
on public.home_members for insert
to authenticated
with check (public.can_manage_members(home_id));

create policy home_members_update_manager
on public.home_members for update
to authenticated
using (public.can_manage_members(home_id))
with check (public.can_manage_members(home_id));

-- Soft-remove preferred; hard delete restricted to managers.
create policy home_members_delete_manager
on public.home_members for delete
to authenticated
using (public.can_manage_members(home_id));

-- ---------------------------------------------------------------------------
-- invitations
-- Token plaintext never stored; only hash + optional short code.
-- ---------------------------------------------------------------------------

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  home_id uuid not null references public.homes (id) on delete cascade,
  role public.home_role not null default 'EDITOR',
  token_hash text not null unique,
  short_code text unique,
  invited_email text,
  created_by_user_id uuid not null references public.profiles (id),
  status public.invitation_status not null default 'ACTIVE',
  expires_at timestamptz not null,
  accepted_by_user_id uuid references public.profiles (id),
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  constraint invitations_role_not_owner check (role <> 'OWNER')
);

create index invitations_home_id_idx on public.invitations (home_id);
create index invitations_active_expires_idx
  on public.invitations (expires_at)
  where status = 'ACTIVE';

alter table public.invitations enable row level security;

create policy invitations_select_manager
on public.invitations for select
to authenticated
using (public.can_manage_members(home_id));

create policy invitations_insert_manager
on public.invitations for insert
to authenticated
with check (
  public.can_manage_members(home_id)
  and created_by_user_id = auth.uid()
);

create policy invitations_update_manager
on public.invitations for update
to authenticated
using (public.can_manage_members(home_id))
with check (public.can_manage_members(home_id));

-- Accept invitation is a trusted RPC (Phase 2), not a direct client update
-- by arbitrary authenticated users.

-- ---------------------------------------------------------------------------
-- rooms
-- ---------------------------------------------------------------------------

create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  home_id uuid not null references public.homes (id) on delete cascade,
  name text not null,
  description text,
  image_id uuid,
  owner_user_id uuid references public.profiles (id),
  sort_order integer not null default 0,
  created_by_user_id uuid not null references public.profiles (id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  archived_at timestamptz
);

create index rooms_home_id_idx on public.rooms (home_id);

create trigger rooms_set_updated_at
before update on public.rooms
for each row execute function public.set_updated_at();

alter table public.rooms enable row level security;

create policy rooms_select_member
on public.rooms for select
to authenticated
using (public.can_view_home(home_id));

create policy rooms_insert_editor
on public.rooms for insert
to authenticated
with check (
  public.can_edit_inventory(home_id)
  and created_by_user_id = auth.uid()
);

create policy rooms_update_editor
on public.rooms for update
to authenticated
using (public.can_edit_inventory(home_id))
with check (public.can_edit_inventory(home_id));

create policy rooms_delete_editor
on public.rooms for delete
to authenticated
using (public.can_edit_inventory(home_id));

-- ---------------------------------------------------------------------------
-- inventory_nodes (unified recursive containment)
-- ---------------------------------------------------------------------------

create table public.inventory_nodes (
  id uuid primary key default gen_random_uuid(),
  home_id uuid not null references public.homes (id) on delete cascade,
  room_id uuid not null references public.rooms (id),
  parent_node_id uuid references public.inventory_nodes (id),
  node_kind public.inventory_node_kind not null,
  name text not null,
  description text,
  is_container boolean not null default false,
  is_mobile_container boolean not null default false,
  item_category public.item_category,
  quantity numeric,
  quantity_unit text,
  minimum_quantity numeric,
  purchase_price numeric,
  currency text,
  purchase_date date,
  expiration_date date,
  brand text,
  model text,
  serial_number text,
  condition text,
  weight numeric,
  weight_unit text,
  owner_user_id uuid references public.profiles (id),
  created_by_user_id uuid not null references public.profiles (id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  archived_at timestamptz,
  constraint inventory_nodes_no_self_parent check (parent_node_id is distinct from id),
  constraint inventory_nodes_mobile_requires_container check (
    not is_mobile_container or is_container
  ),
  constraint inventory_nodes_item_category_for_items check (
    item_category is null or node_kind = 'ITEM'
  )
);

create index inventory_nodes_home_id_idx on public.inventory_nodes (home_id);
create index inventory_nodes_room_id_idx on public.inventory_nodes (room_id);
create index inventory_nodes_parent_idx on public.inventory_nodes (parent_node_id);
create index inventory_nodes_name_trgm_prep_idx on public.inventory_nodes (home_id, name);

create trigger inventory_nodes_set_updated_at
before update on public.inventory_nodes
for each row execute function public.set_updated_at();

-- Keep room/home consistent with parent when nested.
create or replace function public.validate_inventory_node()
returns trigger
language plpgsql
as $$
declare
  parent_rec public.inventory_nodes%rowtype;
  room_home_id uuid;
begin
  select home_id into room_home_id from public.rooms where id = new.room_id;
  if room_home_id is null then
    raise exception 'room_id % does not exist', new.room_id;
  end if;
  if room_home_id <> new.home_id then
    raise exception 'room must belong to the same home as the inventory node';
  end if;

  if new.parent_node_id is not null then
    select * into parent_rec
    from public.inventory_nodes
    where id = new.parent_node_id;

    if parent_rec.id is null then
      raise exception 'parent_node_id % does not exist', new.parent_node_id;
    end if;
    if parent_rec.home_id <> new.home_id then
      raise exception 'parent must belong to the same home';
    end if;
    if not parent_rec.is_container then
      raise exception 'parent must be a container';
    end if;
    if parent_rec.archived_at is not null then
      raise exception 'archived containers cannot receive new items';
    end if;
    -- Nested nodes inherit the parent's room.
    new.room_id := parent_rec.room_id;
  end if;

  return new;
end;
$$;

create trigger inventory_nodes_validate
before insert or update on public.inventory_nodes
for each row execute function public.validate_inventory_node();

alter table public.inventory_nodes enable row level security;

create policy inventory_nodes_select_member
on public.inventory_nodes for select
to authenticated
using (public.can_view_home(home_id));

create policy inventory_nodes_insert_editor
on public.inventory_nodes for insert
to authenticated
with check (
  public.can_edit_inventory(home_id)
  and created_by_user_id = auth.uid()
);

create policy inventory_nodes_update_editor
on public.inventory_nodes for update
to authenticated
using (public.can_edit_inventory(home_id))
with check (public.can_edit_inventory(home_id));

create policy inventory_nodes_delete_editor
on public.inventory_nodes for delete
to authenticated
using (public.can_edit_inventory(home_id));

-- ---------------------------------------------------------------------------
-- Trusted move: prevent cycles; keep descendants with the moved subtree.
-- Room of the entire subtree is updated to the destination room.
-- ---------------------------------------------------------------------------

create or replace function public.move_inventory_node(
  p_node_id uuid,
  p_destination_room_id uuid,
  p_destination_parent_node_id uuid default null
)
returns public.inventory_nodes
language plpgsql
security definer
set search_path = public
as $$
declare
  node_rec public.inventory_nodes%rowtype;
  dest_parent public.inventory_nodes%rowtype;
  dest_room public.rooms%rowtype;
  cycle_hit boolean;
begin
  select * into node_rec from public.inventory_nodes where id = p_node_id;
  if node_rec.id is null then
    raise exception 'inventory node not found';
  end if;

  if not public.can_edit_inventory(node_rec.home_id) then
    raise exception 'not authorized to move inventory in this home';
  end if;

  select * into dest_room from public.rooms where id = p_destination_room_id;
  if dest_room.id is null or dest_room.home_id <> node_rec.home_id then
    raise exception 'destination room must belong to the same home';
  end if;
  if dest_room.archived_at is not null then
    raise exception 'cannot move into an archived room';
  end if;

  if p_destination_parent_node_id is not null then
    if p_destination_parent_node_id = p_node_id then
      raise exception 'a node cannot contain itself';
    end if;

    select * into dest_parent
    from public.inventory_nodes
    where id = p_destination_parent_node_id;

    if dest_parent.id is null or dest_parent.home_id <> node_rec.home_id then
      raise exception 'destination parent must belong to the same home';
    end if;
    if not dest_parent.is_container then
      raise exception 'destination parent must be a container';
    end if;
    if dest_parent.archived_at is not null then
      raise exception 'destination parent is archived';
    end if;

    -- Cycle: destination parent cannot be a descendant of the moved node.
    with recursive descendants as (
      select id from public.inventory_nodes where parent_node_id = p_node_id
      union all
      select n.id
      from public.inventory_nodes n
      inner join descendants d on n.parent_node_id = d.id
    )
    select exists (
      select 1 from descendants where id = p_destination_parent_node_id
    ) into cycle_hit;

    if cycle_hit then
      raise exception 'cyclic containment is not allowed';
    end if;

    -- Nested destination implies its room.
    p_destination_room_id := dest_parent.room_id;
  end if;

  update public.inventory_nodes
  set
    parent_node_id = p_destination_parent_node_id,
    room_id = p_destination_room_id,
    updated_at = timezone('utc', now())
  where id = p_node_id
  returning * into node_rec;

  -- Propagate room_id to all descendants (containment moves with the subtree).
  with recursive subtree as (
    select id from public.inventory_nodes where parent_node_id = p_node_id
    union all
    select n.id
    from public.inventory_nodes n
    inner join subtree s on n.parent_node_id = s.id
  )
  update public.inventory_nodes n
  set
    room_id = p_destination_room_id,
    updated_at = timezone('utc', now())
  from subtree s
  where n.id = s.id;

  return node_rec;
end;
$$;

revoke all on function public.move_inventory_node(uuid, uuid, uuid) from public;
grant execute on function public.move_inventory_node(uuid, uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Accept invitation (trusted)
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
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  token_digest := encode(digest(p_token, 'sha256'), 'hex');

  select * into invite
  from public.invitations
  where token_hash = token_digest
  for update;

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
-- Create invitation helper (returns short metadata; caller supplies raw token)
-- Client generates a random token, sends hash via this function.
-- ---------------------------------------------------------------------------

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
set search_path = public
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
    encode(digest(p_token, 'sha256'), 'hex'),
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
