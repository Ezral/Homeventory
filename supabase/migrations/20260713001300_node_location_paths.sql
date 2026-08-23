-- Location path for inventory nodes: "Room › Furniture › Storage › …"
-- (ancestors only — does not include the node’s own name).

create or replace function public.get_node_location_paths(p_node_ids uuid[])
returns table (
  node_id uuid,
  location_path text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_node_ids is null or cardinality(p_node_ids) = 0 then
    return;
  end if;

  return query
  with recursive walk as (
    select
      n.id as leaf_id,
      n.parent_node_id as next_parent_id,
      n.room_id,
      n.home_id,
      array[]::text[] as ancestor_names
    from public.inventory_nodes n
    where n.id = any (p_node_ids)
      and n.archived_at is null

    union all

    select
      w.leaf_id,
      p.parent_node_id,
      w.room_id,
      w.home_id,
      (array[p.name] || w.ancestor_names)
    from walk w
    join public.inventory_nodes p
      on p.id = w.next_parent_id
     and p.archived_at is null
  ),
  finished as (
    select
      w.leaf_id,
      w.home_id,
      w.room_id,
      w.ancestor_names
    from walk w
    where w.next_parent_id is null
  )
  select
    f.leaf_id as node_id,
    case
      when cardinality(f.ancestor_names) = 0 then r.name
      else r.name || ' › ' || array_to_string(f.ancestor_names, ' › ')
    end as location_path
  from finished f
  join public.rooms r on r.id = f.room_id
  where public.can_view_home(f.home_id);
end;
$$;

revoke all on function public.get_node_location_paths(uuid[]) from public;
grant execute on function public.get_node_location_paths(uuid[]) to authenticated;

comment on function public.get_node_location_paths(uuid[]) is
  'Batch location breadcrumbs: Room › parent containers (excludes the node name).';

-- Packing paths: include room + ancestor chain through the selected root.
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
  v_root_name text;
  v_room_name text;
  v_prefix text;
begin
  select n.home_id, n.name, r.name
  into v_home, v_root_name, v_room_name
  from public.inventory_nodes n
  join public.rooms r on r.id = n.room_id
  where n.id = p_root_node_id;

  if v_home is null then
    raise exception 'node not found' using errcode = 'P0002';
  end if;
  if not public.can_view_home(v_home) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  v_prefix := v_room_name || ' › ' || v_root_name;

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
      (v_prefix || ' › ' || c.name)::text as path_label
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
  v_room_name text;
begin
  select r.home_id, r.name into v_home, v_room_name
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
      (v_room_name || ' › ' || c.name)::text as path_label
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
