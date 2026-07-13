-- Packing plan overlay: items stay in place; PLANNED checklist + PACKED flag.
-- Also list_node_descendants for furniture-scoped multi-select packing.
-- Restore nodes previously relocated by old pack semantics.

-- ---------------------------------------------------------------------------
-- Enum + nullable packed_at for PLANNED rows
-- ---------------------------------------------------------------------------

do $$ begin
  alter type public.trip_item_status add value 'PLANNED';
exception
  when duplicate_object then null;
end $$;

alter table public.trip_items
  alter column packed_at drop not null;

comment on column public.trip_items.packed_at is
  'Set when status becomes PACKED. Null while PLANNED.';

create index if not exists trip_items_packed_node_idx
  on public.trip_items (inventory_node_id)
  where status = 'PACKED';

-- ---------------------------------------------------------------------------
-- Restore inventory locations for currently PACKED items (old move-on-pack)
-- ---------------------------------------------------------------------------

do $$
declare
  r record;
begin
  for r in
    select
      ti.inventory_node_id,
      ti.original_room_id,
      ti.original_parent_node_id
    from public.trip_items ti
    join public.trips t on t.id = ti.trip_id
    where ti.status = 'PACKED'
      and t.archived_at is null
  loop
    begin
      perform public.move_inventory_node(
        r.inventory_node_id,
        r.original_room_id,
        r.original_parent_node_id
      );
    exception when others then
      -- Skip rows whose original parent is gone or move is invalid.
      null;
    end;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- list_node_descendants
-- ---------------------------------------------------------------------------

create or replace function public.list_node_descendants(p_root_node_id uuid)
returns table (
  id uuid,
  home_id uuid,
  room_id uuid,
  parent_node_id uuid,
  node_kind public.inventory_node_kind,
  name text,
  is_container boolean,
  is_mobile_container boolean,
  depth integer,
  path_label text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_home uuid;
begin
  select n.home_id into v_home
  from public.inventory_nodes n
  where n.id = p_root_node_id;

  if v_home is null then
    raise exception 'node not found' using errcode = 'P0002';
  end if;
  if not public.can_view_home(v_home) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  return query
  with recursive tree as (
    select
      c.id,
      c.home_id,
      c.room_id,
      c.parent_node_id,
      c.node_kind,
      c.name,
      c.is_container,
      c.is_mobile_container,
      1 as depth,
      c.name::text as path_label
    from public.inventory_nodes c
    where c.parent_node_id = p_root_node_id
      and c.archived_at is null
      and coalesce(c.is_disposed, false) = false

    union all

    select
      c.id,
      c.home_id,
      c.room_id,
      c.parent_node_id,
      c.node_kind,
      c.name,
      c.is_container,
      c.is_mobile_container,
      t.depth + 1,
      (t.path_label || ' › ' || c.name)::text
    from public.inventory_nodes c
    join tree t on c.parent_node_id = t.id
    where c.archived_at is null
      and coalesce(c.is_disposed, false) = false
  )
  select
    tree.id,
    tree.home_id,
    tree.room_id,
    tree.parent_node_id,
    tree.node_kind,
    tree.name,
    tree.is_container,
    tree.is_mobile_container,
    tree.depth,
    tree.path_label
  from tree
  order by tree.path_label;
end;
$$;

revoke all on function public.list_node_descendants(uuid) from public;
grant execute on function public.list_node_descendants(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- pack / unpack without relocating inventory
-- ---------------------------------------------------------------------------

create or replace function public.pack_item_into_container(
  p_trip_id uuid,
  p_node_id uuid,
  p_packed_into_node_id uuid
)
returns public.trip_items
language plpgsql
security definer
set search_path = public
as $$
declare
  trip_rec public.trips%rowtype;
  node_rec public.inventory_nodes%rowtype;
  bag_rec public.inventory_nodes%rowtype;
  item public.trip_items%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  select * into trip_rec from public.trips where id = p_trip_id;
  if trip_rec.id is null or trip_rec.archived_at is not null then
    raise exception 'trip not found';
  end if;
  if not public.can_edit_inventory(trip_rec.home_id) then
    raise exception 'not authorized';
  end if;

  select * into node_rec from public.inventory_nodes where id = p_node_id for update;
  select * into bag_rec from public.inventory_nodes where id = p_packed_into_node_id;

  if node_rec.id is null or bag_rec.id is null then
    raise exception 'inventory node not found';
  end if;
  if node_rec.home_id <> trip_rec.home_id or bag_rec.home_id <> trip_rec.home_id then
    raise exception 'nodes must belong to the trip home';
  end if;
  if node_rec.is_disposed or node_rec.archived_at is not null then
    raise exception 'cannot pack disposed or archived item';
  end if;
  if not bag_rec.is_container then
    raise exception 'pack destination must be a container';
  end if;
  if not exists (
    select 1 from public.trip_containers tc
    where tc.trip_id = p_trip_id and tc.inventory_node_id = p_packed_into_node_id
  ) then
    raise exception 'destination container is not assigned to this trip';
  end if;
  if p_node_id = p_packed_into_node_id then
    raise exception 'cannot pack a container into itself';
  end if;

  insert into public.trip_items (
    home_id,
    trip_id,
    inventory_node_id,
    packed_into_node_id,
    original_room_id,
    original_parent_node_id,
    status,
    packed_at,
    unpacked_at,
    packed_by_user_id
  ) values (
    trip_rec.home_id,
    p_trip_id,
    p_node_id,
    p_packed_into_node_id,
    node_rec.room_id,
    node_rec.parent_node_id,
    'PACKED',
    timezone('utc', now()),
    null,
    auth.uid()
  )
  on conflict (trip_id, inventory_node_id) do update
  set
    packed_into_node_id = excluded.packed_into_node_id,
    original_room_id = excluded.original_room_id,
    original_parent_node_id = excluded.original_parent_node_id,
    status = 'PACKED',
    packed_at = timezone('utc', now()),
    unpacked_at = null,
    packed_by_user_id = auth.uid()
  returning * into item;

  update public.trips
  set status = case when status = 'PLANNED' then 'ACTIVE'::public.trip_status else status end,
      updated_at = timezone('utc', now())
  where id = p_trip_id;

  -- Location intentionally unchanged — packing is an overlay checklist.
  return item;
end;
$$;

revoke all on function public.pack_item_into_container(uuid, uuid, uuid) from public;
grant execute on function public.pack_item_into_container(uuid, uuid, uuid) to authenticated;

create or replace function public.unpack_item(p_trip_item_id uuid)
returns public.trip_items
language plpgsql
security definer
set search_path = public
as $$
declare
  item public.trip_items%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  select * into item from public.trip_items where id = p_trip_item_id for update;
  if item.id is null then
    raise exception 'trip item not found';
  end if;
  if not public.can_edit_inventory(item.home_id) then
    raise exception 'not authorized';
  end if;
  if item.status <> 'PACKED' then
    raise exception 'item is not packed';
  end if;

  -- Return to packing plan (unchecked), do not relocate inventory.
  update public.trip_items
  set
    status = 'PLANNED',
    unpacked_at = timezone('utc', now())
  where id = item.id
  returning * into item;

  return item;
end;
$$;

revoke all on function public.unpack_item(uuid) from public;
grant execute on function public.unpack_item(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Batch add to packing plan (PLANNED)
-- ---------------------------------------------------------------------------

create or replace function public.add_items_to_packing_plan(
  p_trip_id uuid,
  p_node_ids uuid[],
  p_packed_into_node_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  trip_rec public.trips%rowtype;
  bag_rec public.inventory_nodes%rowtype;
  node_id uuid;
  node_rec public.inventory_nodes%rowtype;
  upserted_id uuid;
  added integer := 0;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  select * into trip_rec from public.trips where id = p_trip_id;
  if trip_rec.id is null or trip_rec.archived_at is not null then
    raise exception 'trip not found';
  end if;
  if not public.can_edit_inventory(trip_rec.home_id) then
    raise exception 'not authorized';
  end if;

  select * into bag_rec from public.inventory_nodes where id = p_packed_into_node_id;
  if bag_rec.id is null or not bag_rec.is_container then
    raise exception 'pack destination must be a container';
  end if;
  if not exists (
    select 1 from public.trip_containers tc
    where tc.trip_id = p_trip_id and tc.inventory_node_id = p_packed_into_node_id
  ) then
    raise exception 'destination container is not assigned to this trip';
  end if;

  if p_node_ids is null then
    return 0;
  end if;

  foreach node_id in array p_node_ids loop
    if node_id = p_packed_into_node_id then
      continue;
    end if;
    select * into node_rec from public.inventory_nodes where id = node_id;
    if node_rec.id is null then
      continue;
    end if;
    if node_rec.home_id <> trip_rec.home_id then
      continue;
    end if;
    if node_rec.is_disposed or node_rec.archived_at is not null then
      continue;
    end if;

    upserted_id := null;
    insert into public.trip_items (
      home_id,
      trip_id,
      inventory_node_id,
      packed_into_node_id,
      original_room_id,
      original_parent_node_id,
      status,
      packed_at,
      packed_by_user_id
    ) values (
      trip_rec.home_id,
      p_trip_id,
      node_id,
      p_packed_into_node_id,
      node_rec.room_id,
      node_rec.parent_node_id,
      'PLANNED',
      null,
      auth.uid()
    )
    on conflict (trip_id, inventory_node_id) do update
    set
      packed_into_node_id = excluded.packed_into_node_id,
      original_room_id = excluded.original_room_id,
      original_parent_node_id = excluded.original_parent_node_id
    where public.trip_items.status <> 'PACKED'
    returning id into upserted_id;

    if upserted_id is not null then
      added := added + 1;
    end if;
  end loop;

  return added;
end;
$$;

revoke all on function public.add_items_to_packing_plan(uuid, uuid[], uuid) from public;
grant execute on function public.add_items_to_packing_plan(uuid, uuid[], uuid) to authenticated;

create or replace function public.remove_from_packing_plan(p_trip_item_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  item public.trip_items%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  select * into item from public.trip_items where id = p_trip_item_id;
  if item.id is null then
    raise exception 'trip item not found';
  end if;
  if not public.can_edit_inventory(item.home_id) then
    raise exception 'not authorized';
  end if;
  if item.status = 'PACKED' then
    raise exception 'unpack before removing from plan';
  end if;

  delete from public.trip_items where id = p_trip_item_id;
end;
$$;

revoke all on function public.remove_from_packing_plan(uuid) from public;
grant execute on function public.remove_from_packing_plan(uuid) to authenticated;

-- Active packed overlays for a home (room browse greying).
create or replace function public.list_home_packed_nodes(p_home_id uuid)
returns table (
  inventory_node_id uuid,
  trip_id uuid,
  trip_name text,
  packed_into_node_id uuid,
  packed_into_name text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.can_view_home(p_home_id) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  return query
  select
    ti.inventory_node_id,
    t.id,
    t.name,
    ti.packed_into_node_id,
    bag.name
  from public.trip_items ti
  join public.trips t on t.id = ti.trip_id
  left join public.inventory_nodes bag on bag.id = ti.packed_into_node_id
  where ti.home_id = p_home_id
    and ti.status = 'PACKED'
    and t.archived_at is null
  order by t.name, bag.name;
end;
$$;

revoke all on function public.list_home_packed_nodes(uuid) from public;
grant execute on function public.list_home_packed_nodes(uuid) to authenticated;
