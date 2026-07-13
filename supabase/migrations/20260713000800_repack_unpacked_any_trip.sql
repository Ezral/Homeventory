-- Allow UNPACKED (and other non-PACKED) trip_items to be put back on a packing
-- plan for the same or any other trip. Unique key is (trip_id, inventory_node_id),
-- so cross-trip inserts already work; same-trip revival must reset status.

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
      unpacked_at,
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
      null,
      auth.uid()
    )
    on conflict (trip_id, inventory_node_id) do update
    set
      packed_into_node_id = excluded.packed_into_node_id,
      original_room_id = excluded.original_room_id,
      original_parent_node_id = excluded.original_parent_node_id,
      status = 'PLANNED',
      packed_at = null,
      unpacked_at = null,
      packed_by_user_id = auth.uid()
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

comment on function public.add_items_to_packing_plan(uuid, uuid[], uuid) is
  'Add inventory nodes to a trip packing plan as PLANNED. Revives UNPACKED rows on the same trip; inserts new rows for other trips. Skips rows that are already PACKED on the target trip.';
