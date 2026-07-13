-- Multi-dispenser per-slot chambers: each linked product has its own fill
-- against the dispenser's capacity (e.g. 300 CC × 2 slots = two chambers).

alter table public.dispenser_product_assignments
  add column if not exists capacity numeric,
  add column if not exists quantity numeric not null default 0,
  add column if not exists quantity_unit text;

comment on column public.dispenser_product_assignments.capacity is
  'Per-chamber max fill. Defaults from dispenser.capacity at assign time.';
comment on column public.dispenser_product_assignments.quantity is
  'Remaining volume in this chamber.';

alter table public.inventory_transactions
  add column if not exists slot_number smallint
    check (slot_number is null or slot_number between 1 and 3);

comment on column public.inventory_transactions.slot_number is
  'When set, stock change applied to a multi-dispenser chamber slot.';

-- Backfill chamber capacity from dispenser; migrate shared node quantity when
-- a MULTI dispenser has exactly one assignment.
update public.dispenser_product_assignments a
set
  capacity = coalesce(a.capacity, d.capacity),
  quantity_unit = coalesce(a.quantity_unit, d.quantity_unit, 'CC')
from public.inventory_nodes d
where a.dispenser_item_id = d.id
  and d.is_dispenser = true;

update public.dispenser_product_assignments a
set quantity = coalesce(d.quantity, 0)
from public.inventory_nodes d
where a.dispenser_item_id = d.id
  and d.is_dispenser = true
  and d.dispenser_mode = 'MULTI'
  and coalesce(d.quantity, 0) > 0
  and a.quantity = 0
  and (
    select count(*) from public.dispenser_product_assignments x
    where x.dispenser_item_id = d.id
  ) = 1;

-- ---------------------------------------------------------------------------
-- assign_product_to_dispenser: init / keep chamber fill
-- ---------------------------------------------------------------------------

create or replace function public.assign_product_to_dispenser(
  p_dispenser_item_id uuid,
  p_product_item_id uuid,
  p_slot_number integer
)
returns public.dispenser_product_assignments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_disp public.inventory_nodes%rowtype;
  v_prod public.inventory_nodes%rowtype;
  v_max_slots integer;
  v_row public.dispenser_product_assignments%rowtype;
  v_prev_qty numeric := 0;
  v_prev_unit text;
  v_capacity numeric;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select * into v_disp from public.inventory_nodes where id = p_dispenser_item_id;
  if not found then
    raise exception 'dispenser not found' using errcode = 'P0002';
  end if;
  if not public.can_edit_inventory(v_disp.home_id) then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  if not coalesce(v_disp.is_dispenser, false) then
    raise exception 'target is not a dispenser' using errcode = '22023';
  end if;
  if v_disp.is_disposed or v_disp.archived_at is not null then
    raise exception 'dispenser is inactive' using errcode = '22023';
  end if;

  v_max_slots := case
    when v_disp.dispenser_mode = 'MULTI' then 3
    else 1
  end;
  if p_slot_number is null or p_slot_number < 1 or p_slot_number > v_max_slots then
    raise exception 'invalid slot for dispenser mode' using errcode = '22023';
  end if;

  select * into v_prod from public.inventory_nodes where id = p_product_item_id;
  if not found then
    raise exception 'product not found' using errcode = 'P0002';
  end if;
  if v_prod.home_id <> v_disp.home_id then
    raise exception 'product must belong to the same home' using errcode = '22023';
  end if;
  if not coalesce(v_prod.is_dispensable, false) then
    raise exception 'product is not marked dispensable' using errcode = '22023';
  end if;
  if v_prod.is_disposed or v_prod.archived_at is not null then
    raise exception 'product is inactive' using errcode = '22023';
  end if;
  if coalesce(v_prod.is_dispenser, false) then
    raise exception 'cannot link a dispenser as a product' using errcode = '22023';
  end if;

  select quantity, quantity_unit
  into v_prev_qty, v_prev_unit
  from public.dispenser_product_assignments
  where dispenser_item_id = p_dispenser_item_id
    and slot_number = p_slot_number;
  if not found then
    v_prev_qty := 0;
    v_prev_unit := null;
  end if;

  v_capacity := v_disp.capacity;

  delete from public.dispenser_product_assignments
  where dispenser_item_id = p_dispenser_item_id
    and slot_number = p_slot_number;

  delete from public.dispenser_product_assignments
  where dispenser_item_id = p_dispenser_item_id
    and product_item_id = p_product_item_id;

  insert into public.dispenser_product_assignments (
    home_id,
    dispenser_item_id,
    product_item_id,
    slot_number,
    capacity,
    quantity,
    quantity_unit,
    created_by
  ) values (
    v_disp.home_id,
    p_dispenser_item_id,
    p_product_item_id,
    p_slot_number,
    v_capacity,
    least(coalesce(v_prev_qty, 0), coalesce(v_capacity, coalesce(v_prev_qty, 0))),
    coalesce(v_prev_unit, v_disp.quantity_unit, 'CC'),
    auth.uid()
  )
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.assign_product_to_dispenser(uuid, uuid, integer) from public;
grant execute on function public.assign_product_to_dispenser(uuid, uuid, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- apply_inventory_transaction: optional p_slot_number for MULTI chambers
-- ---------------------------------------------------------------------------

drop function if exists public.apply_inventory_transaction(
  uuid,
  public.inventory_transaction_type,
  numeric,
  text,
  text,
  uuid
);

create or replace function public.apply_inventory_transaction(
  p_node_id uuid,
  p_transaction_type public.inventory_transaction_type,
  p_quantity_delta numeric default null,
  p_quantity_unit text default null,
  p_reason text default null,
  p_related_node_id uuid default null,
  p_slot_number integer default null
)
returns public.inventory_transactions
language plpgsql
security definer
set search_path = public
as $$
declare
  node_rec public.inventory_nodes%rowtype;
  related_rec public.inventory_nodes%rowtype;
  slot_rec public.dispenser_product_assignments%rowtype;
  qty_before numeric;
  qty_after numeric;
  delta numeric;
  tx public.inventory_transactions%rowtype;
  unit text;
  slot_capacity numeric;
  use_slot boolean := false;
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

  use_slot :=
    coalesce(node_rec.is_dispenser, false)
    and node_rec.dispenser_mode = 'MULTI'
    and p_transaction_type in (
      'USE', 'RESTOCK', 'ADJUSTMENT', 'INITIAL_STOCK', 'TRANSFER_REFILL'
    );

  if use_slot then
    if p_slot_number is null then
      raise exception 'multi dispenser stock changes require slot_number';
    end if;
    select * into slot_rec
    from public.dispenser_product_assignments
    where dispenser_item_id = p_node_id
      and slot_number = p_slot_number
    for update;
    if not found then
      raise exception 'dispenser slot is empty; assign a product first';
    end if;
    qty_before := coalesce(slot_rec.quantity, 0);
    slot_capacity := coalesce(slot_rec.capacity, node_rec.capacity);
    unit := coalesce(
      nullif(trim(p_quantity_unit), ''),
      slot_rec.quantity_unit,
      node_rec.quantity_unit,
      'CC'
    );
  else
    if p_slot_number is not null
       and p_transaction_type in (
         'USE', 'RESTOCK', 'ADJUSTMENT', 'INITIAL_STOCK', 'TRANSFER_REFILL'
       ) then
      raise exception 'slot_number is only valid for multi dispensers';
    end if;
    qty_before := coalesce(node_rec.quantity, 0);
    unit := coalesce(nullif(trim(p_quantity_unit), ''), node_rec.quantity_unit);
  end if;

  delta := coalesce(p_quantity_delta, 0);

  case p_transaction_type
    when 'USE' then
      if delta = 0 then
        raise exception 'USE requires a non-zero quantity_delta';
      end if;
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
      if use_slot then
        if slot_capacity is not null and qty_after > slot_capacity then
          raise exception 'restock would exceed chamber capacity';
        end if;
      elsif node_rec.capacity is not null and qty_after > node_rec.capacity then
        raise exception 'restock would exceed capacity';
      end if;
    when 'ADJUSTMENT' then
      qty_after := qty_before + delta;
      if qty_after < 0 then
        raise exception 'adjustment cannot result in negative quantity';
      end if;
      if use_slot then
        if slot_capacity is not null and qty_after > slot_capacity then
          raise exception 'adjustment would exceed chamber capacity';
        end if;
      elsif node_rec.capacity is not null and qty_after > node_rec.capacity then
        raise exception 'adjustment would exceed capacity';
      end if;
    when 'INITIAL_STOCK' then
      delta := abs(coalesce(p_quantity_delta, qty_before));
      qty_after := delta;
      delta := qty_after - qty_before;
      if use_slot then
        if slot_capacity is not null and qty_after > slot_capacity then
          raise exception 'initial stock would exceed chamber capacity';
        end if;
      end if;
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
      if use_slot then
        if slot_capacity is not null and qty_after > slot_capacity then
          raise exception 'refill would exceed chamber capacity';
        end if;
      elsif node_rec.capacity is not null and qty_after > node_rec.capacity then
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
        slot_number,
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
        case when use_slot then p_slot_number else null end,
        auth.uid()
      );
    when 'MOVE' then
      qty_after := qty_before;
      delta := 0;
    else
      raise exception 'unsupported transaction type';
  end case;

  if p_transaction_type <> 'DISPOSE' and p_transaction_type <> 'MOVE' then
    if use_slot then
      update public.dispenser_product_assignments
      set
        quantity = qty_after,
        quantity_unit = coalesce(unit, quantity_unit),
        capacity = coalesce(capacity, slot_capacity)
      where id = slot_rec.id;
    else
      update public.inventory_nodes
      set
        quantity = qty_after,
        quantity_unit = coalesce(unit, quantity_unit),
        updated_at = timezone('utc', now())
      where id = node_rec.id;
    end if;
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
    slot_number,
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
    case when use_slot then p_slot_number else null end,
    auth.uid()
  )
  returning * into tx;

  return tx;
end;
$$;

revoke all on function public.apply_inventory_transaction(
  uuid,
  public.inventory_transaction_type,
  numeric,
  text,
  text,
  uuid,
  integer
) from public;
grant execute on function public.apply_inventory_transaction(
  uuid,
  public.inventory_transaction_type,
  numeric,
  text,
  text,
  uuid,
  integer
) to authenticated;
