-- Phase 6-super MVP: dispose, dispenser fields, inventory transactions, trips.
-- Stock ledger + pack/unpack with original location snapshot.

-- ---------------------------------------------------------------------------
-- inventory_nodes: dispose + dispenser
-- ---------------------------------------------------------------------------

alter table public.inventory_nodes
  add column if not exists is_disposed boolean not null default false,
  add column if not exists disposed_at timestamptz,
  add column if not exists is_dispenser boolean not null default false,
  add column if not exists capacity numeric;

create index if not exists inventory_nodes_home_active_idx
  on public.inventory_nodes (home_id, room_id)
  where archived_at is null and is_disposed = false;

-- ---------------------------------------------------------------------------
-- inventory_transactions
-- ---------------------------------------------------------------------------

do $$
begin
  if not exists (
    select 1 from pg_type where typname = 'inventory_transaction_type'
  ) then
    create type public.inventory_transaction_type as enum (
      'INITIAL_STOCK',
      'USE',
      'RESTOCK',
      'ADJUSTMENT',
      'DISPOSE',
      'TRANSFER_REFILL',
      'MOVE'
    );
  end if;
end $$;

create table if not exists public.inventory_transactions (
  id uuid primary key default gen_random_uuid(),
  home_id uuid not null references public.homes (id) on delete cascade,
  inventory_node_id uuid not null references public.inventory_nodes (id),
  related_node_id uuid references public.inventory_nodes (id),
  transaction_type public.inventory_transaction_type not null,
  quantity_delta numeric,
  quantity_before numeric,
  quantity_after numeric,
  quantity_unit text,
  reason text,
  created_by_user_id uuid not null references public.profiles (id),
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists inventory_transactions_node_idx
  on public.inventory_transactions (inventory_node_id, created_at desc);
create index if not exists inventory_transactions_home_idx
  on public.inventory_transactions (home_id, created_at desc);

alter table public.inventory_transactions enable row level security;

drop policy if exists inventory_transactions_select_member on public.inventory_transactions;
create policy inventory_transactions_select_member
on public.inventory_transactions for select
to authenticated
using (public.can_view_home(home_id));

drop policy if exists inventory_transactions_insert_editor on public.inventory_transactions;
create policy inventory_transactions_insert_editor
on public.inventory_transactions for insert
to authenticated
with check (
  public.can_edit_inventory(home_id)
  and created_by_user_id = auth.uid()
);

-- No client update/delete of ledger rows.
drop policy if exists inventory_transactions_no_update on public.inventory_transactions;
create policy inventory_transactions_no_update
on public.inventory_transactions for update
to authenticated
using (false);

drop policy if exists inventory_transactions_no_delete on public.inventory_transactions;
create policy inventory_transactions_no_delete
on public.inventory_transactions for delete
to authenticated
using (false);

grant select, insert on public.inventory_transactions to authenticated;

-- ---------------------------------------------------------------------------
-- apply_inventory_transaction
-- ---------------------------------------------------------------------------

create or replace function public.apply_inventory_transaction(
  p_node_id uuid,
  p_transaction_type public.inventory_transaction_type,
  p_quantity_delta numeric default null,
  p_quantity_unit text default null,
  p_reason text default null,
  p_related_node_id uuid default null
)
returns public.inventory_transactions
language plpgsql
security definer
set search_path = public
as $$
declare
  node_rec public.inventory_nodes%rowtype;
  related_rec public.inventory_nodes%rowtype;
  qty_before numeric;
  qty_after numeric;
  delta numeric;
  tx public.inventory_transactions%rowtype;
  unit text;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  select * into node_rec from public.inventory_nodes where id = p_node_id for update;
  if node_rec.id is null then
    raise exception 'inventory node not found';
  end if;
  if not public.can_edit_inventory(node_rec.home_id) then
    raise exception 'not authorized to edit inventory in this home';
  end if;
  if node_rec.archived_at is not null then
    raise exception 'cannot change archived inventory';
  end if;
  if node_rec.is_disposed and p_transaction_type <> 'DISPOSE' then
    raise exception 'cannot change disposed inventory';
  end if;

  qty_before := coalesce(node_rec.quantity, 0);
  unit := coalesce(nullif(trim(p_quantity_unit), ''), node_rec.quantity_unit);
  delta := coalesce(p_quantity_delta, 0);

  case p_transaction_type
    when 'USE' then
      if delta = 0 then
        raise exception 'USE requires a non-zero quantity_delta';
      end if;
      -- Accept negative or positive; normalize to debit.
      delta := -abs(delta);
      qty_after := qty_before + delta;
      if qty_after < 0 then
        raise exception 'insufficient quantity for USE';
      end if;
    when 'RESTOCK' then
      if delta = 0 then
        raise exception 'RESTOCK requires a non-zero quantity_delta';
      end if;
      delta := abs(delta);
      qty_after := qty_before + delta;
      if node_rec.capacity is not null and qty_after > node_rec.capacity then
        raise exception 'restock would exceed capacity';
      end if;
    when 'ADJUSTMENT' then
      -- Absolute target when p_quantity_delta is the new quantity encoded as delta from before:
      -- clients send signed delta (after - before).
      qty_after := qty_before + delta;
      if qty_after < 0 then
        raise exception 'adjustment cannot result in negative quantity';
      end if;
      if node_rec.capacity is not null and qty_after > node_rec.capacity then
        raise exception 'adjustment would exceed capacity';
      end if;
    when 'INITIAL_STOCK' then
      delta := abs(coalesce(p_quantity_delta, qty_before));
      qty_after := delta;
      delta := qty_after - qty_before;
    when 'DISPOSE' then
      qty_after := qty_before;
      delta := 0;
      update public.inventory_nodes
      set
        is_disposed = true,
        disposed_at = timezone('utc', now()),
        updated_at = timezone('utc', now())
      where id = node_rec.id;
    when 'TRANSFER_REFILL' then
      if p_related_node_id is null then
        raise exception 'TRANSFER_REFILL requires related_node_id (source)';
      end if;
      if delta = 0 then
        raise exception 'TRANSFER_REFILL requires a non-zero quantity_delta';
      end if;
      delta := abs(delta);
      select * into related_rec
      from public.inventory_nodes
      where id = p_related_node_id
      for update;
      if related_rec.id is null or related_rec.home_id <> node_rec.home_id then
        raise exception 'refill source must belong to the same home';
      end if;
      if related_rec.is_disposed or related_rec.archived_at is not null then
        raise exception 'refill source is not available';
      end if;
      if coalesce(related_rec.quantity, 0) < delta then
        raise exception 'insufficient quantity in refill source';
      end if;
      qty_after := qty_before + delta;
      if node_rec.capacity is not null and qty_after > node_rec.capacity then
        raise exception 'refill would exceed dispenser capacity';
      end if;
      update public.inventory_nodes
      set
        quantity = coalesce(quantity, 0) - delta,
        updated_at = timezone('utc', now())
      where id = related_rec.id;
      insert into public.inventory_transactions (
        home_id,
        inventory_node_id,
        related_node_id,
        transaction_type,
        quantity_delta,
        quantity_before,
        quantity_after,
        quantity_unit,
        reason,
        created_by_user_id
      ) values (
        related_rec.home_id,
        related_rec.id,
        node_rec.id,
        'TRANSFER_REFILL',
        -delta,
        coalesce(related_rec.quantity, 0),
        coalesce(related_rec.quantity, 0) - delta,
        unit,
        p_reason,
        auth.uid()
      );
    when 'MOVE' then
      qty_after := qty_before;
      delta := 0;
    else
      raise exception 'unsupported transaction type';
  end case;

  if p_transaction_type <> 'DISPOSE' and p_transaction_type <> 'MOVE' then
    update public.inventory_nodes
    set
      quantity = qty_after,
      quantity_unit = coalesce(unit, quantity_unit),
      updated_at = timezone('utc', now())
    where id = node_rec.id;
  elsif p_transaction_type = 'DISPOSE' then
    null;
  end if;

  insert into public.inventory_transactions (
    home_id,
    inventory_node_id,
    related_node_id,
    transaction_type,
    quantity_delta,
    quantity_before,
    quantity_after,
    quantity_unit,
    reason,
    created_by_user_id
  ) values (
    node_rec.home_id,
    node_rec.id,
    p_related_node_id,
    p_transaction_type,
    delta,
    qty_before,
    case when p_transaction_type = 'DISPOSE' then qty_before else qty_after end,
    unit,
    p_reason,
    auth.uid()
  )
  returning * into tx;

  return tx;
end;
$$;

revoke all on function public.apply_inventory_transaction(
  uuid, public.inventory_transaction_type, numeric, text, text, uuid
) from public;
grant execute on function public.apply_inventory_transaction(
  uuid, public.inventory_transaction_type, numeric, text, text, uuid
) to authenticated;

-- ---------------------------------------------------------------------------
-- trips
-- ---------------------------------------------------------------------------

do $$
begin
  if not exists (select 1 from pg_type where typname = 'trip_status') then
    create type public.trip_status as enum (
      'PLANNED',
      'ACTIVE',
      'COMPLETED',
      'CANCELLED'
    );
  end if;
  if not exists (select 1 from pg_type where typname = 'trip_item_status') then
    create type public.trip_item_status as enum (
      'PACKED',
      'UNPACKED'
    );
  end if;
end $$;

create table if not exists public.trips (
  id uuid primary key default gen_random_uuid(),
  home_id uuid not null references public.homes (id) on delete cascade,
  name text not null,
  notes text,
  status public.trip_status not null default 'PLANNED',
  starts_on date,
  ends_on date,
  created_by_user_id uuid not null references public.profiles (id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists trips_home_id_idx on public.trips (home_id);

drop trigger if exists trips_set_updated_at on public.trips;
create trigger trips_set_updated_at
before update on public.trips
for each row execute function public.set_updated_at();

alter table public.trips enable row level security;

drop policy if exists trips_select_member on public.trips;
create policy trips_select_member
on public.trips for select
to authenticated
using (public.can_view_home(home_id));

drop policy if exists trips_insert_editor on public.trips;
create policy trips_insert_editor
on public.trips for insert
to authenticated
with check (
  public.can_edit_inventory(home_id)
  and created_by_user_id = auth.uid()
);

drop policy if exists trips_update_editor on public.trips;
create policy trips_update_editor
on public.trips for update
to authenticated
using (public.can_edit_inventory(home_id))
with check (public.can_edit_inventory(home_id));

drop policy if exists trips_delete_editor on public.trips;
create policy trips_delete_editor
on public.trips for delete
to authenticated
using (public.can_edit_inventory(home_id));

create table if not exists public.trip_containers (
  id uuid primary key default gen_random_uuid(),
  home_id uuid not null references public.homes (id) on delete cascade,
  trip_id uuid not null references public.trips (id) on delete cascade,
  inventory_node_id uuid not null references public.inventory_nodes (id),
  created_at timestamptz not null default timezone('utc', now()),
  unique (trip_id, inventory_node_id)
);

create index if not exists trip_containers_trip_idx on public.trip_containers (trip_id);

alter table public.trip_containers enable row level security;

drop policy if exists trip_containers_select_member on public.trip_containers;
create policy trip_containers_select_member
on public.trip_containers for select
to authenticated
using (public.can_view_home(home_id));

drop policy if exists trip_containers_insert_editor on public.trip_containers;
create policy trip_containers_insert_editor
on public.trip_containers for insert
to authenticated
with check (public.can_edit_inventory(home_id));

drop policy if exists trip_containers_delete_editor on public.trip_containers;
create policy trip_containers_delete_editor
on public.trip_containers for delete
to authenticated
using (public.can_edit_inventory(home_id));

create table if not exists public.trip_items (
  id uuid primary key default gen_random_uuid(),
  home_id uuid not null references public.homes (id) on delete cascade,
  trip_id uuid not null references public.trips (id) on delete cascade,
  inventory_node_id uuid not null references public.inventory_nodes (id),
  packed_into_node_id uuid not null references public.inventory_nodes (id),
  original_room_id uuid not null references public.rooms (id),
  original_parent_node_id uuid references public.inventory_nodes (id),
  status public.trip_item_status not null default 'PACKED',
  packed_at timestamptz not null default timezone('utc', now()),
  unpacked_at timestamptz,
  packed_by_user_id uuid not null references public.profiles (id),
  unique (trip_id, inventory_node_id)
);

create index if not exists trip_items_trip_idx on public.trip_items (trip_id, status);

alter table public.trip_items enable row level security;

drop policy if exists trip_items_select_member on public.trip_items;
create policy trip_items_select_member
on public.trip_items for select
to authenticated
using (public.can_view_home(home_id));

drop policy if exists trip_items_insert_editor on public.trip_items;
create policy trip_items_insert_editor
on public.trip_items for insert
to authenticated
with check (
  public.can_edit_inventory(home_id)
  and packed_by_user_id = auth.uid()
);

drop policy if exists trip_items_update_editor on public.trip_items;
create policy trip_items_update_editor
on public.trip_items for update
to authenticated
using (public.can_edit_inventory(home_id))
with check (public.can_edit_inventory(home_id));

grant select, insert, update, delete on public.trips to authenticated;
grant select, insert, delete on public.trip_containers to authenticated;
grant select, insert, update on public.trip_items to authenticated;

-- ---------------------------------------------------------------------------
-- pack / unpack
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
  if trip_rec.id is null then
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
    packed_by_user_id
  ) values (
    trip_rec.home_id,
    p_trip_id,
    p_node_id,
    p_packed_into_node_id,
    node_rec.room_id,
    node_rec.parent_node_id,
    'PACKED',
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

  perform public.move_inventory_node(
    p_node_id,
    bag_rec.room_id,
    p_packed_into_node_id
  );

  perform public.apply_inventory_transaction(
    p_node_id,
    'MOVE',
    0,
    node_rec.quantity_unit,
    'Packed into trip container',
    p_packed_into_node_id
  );

  update public.trips
  set status = case when status = 'PLANNED' then 'ACTIVE'::public.trip_status else status end,
      updated_at = timezone('utc', now())
  where id = p_trip_id;

  return item;
end;
$$;

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

  perform public.move_inventory_node(
    item.inventory_node_id,
    item.original_room_id,
    item.original_parent_node_id
  );

  perform public.apply_inventory_transaction(
    item.inventory_node_id,
    'MOVE',
    0,
    null,
    'Unpacked to original location',
    item.packed_into_node_id
  );

  update public.trip_items
  set
    status = 'UNPACKED',
    unpacked_at = timezone('utc', now())
  where id = item.id
  returning * into item;

  return item;
end;
$$;

revoke all on function public.pack_item_into_container(uuid, uuid, uuid) from public;
revoke all on function public.unpack_item(uuid) from public;
grant execute on function public.pack_item_into_container(uuid, uuid, uuid) to authenticated;
grant execute on function public.unpack_item(uuid) to authenticated;
