-- Room-scoped packable nodes for trip packing multi-select.
-- Walks the full room tree (including under furniture) but returns only
-- non-furniture nodes (ITEM / STORAGE_LOCATION) with path labels.

create or replace function public.list_room_packable_nodes(p_room_id uuid)
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
  select r.home_id into v_home
  from public.rooms r
  where r.id = p_room_id
    and r.archived_at is null;

  if v_home is null then
    raise exception 'room not found' using errcode = 'P0002';
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
      0 as depth,
      c.name::text as path_label
    from public.inventory_nodes c
    where c.room_id = p_room_id
      and c.parent_node_id is null
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
  where tree.node_kind = 'ITEM'::public.inventory_node_kind
  order by tree.path_label;
end;
$$;

revoke all on function public.list_room_packable_nodes(uuid) from public;
grant execute on function public.list_room_packable_nodes(uuid) to authenticated;

comment on function public.list_room_packable_nodes(uuid) is
  'Non-furniture ITEM nodes in a room (any depth), with path labels for packing multi-select.';
