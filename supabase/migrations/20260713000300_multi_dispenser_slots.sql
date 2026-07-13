-- Multi-dispenser product slots (Phase H).

do $$ begin
  create type public.dispenser_mode as enum ('SINGLE', 'MULTI');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.consumable_form as enum (
    'LIQUID',
    'GEL',
    'CREAM',
    'FOAM',
    'POWDER',
    'OTHER'
  );
exception when duplicate_object then null;
end $$;

alter table public.inventory_nodes
  add column if not exists dispenser_mode public.dispenser_mode,
  add column if not exists is_dispensable boolean not null default false,
  add column if not exists consumable_form public.consumable_form;

comment on column public.inventory_nodes.dispenser_mode is
  'SINGLE = 1 linked product; MULTI = up to 3 slots. Null when not a dispenser.';
comment on column public.inventory_nodes.is_dispensable is
  'When true, this item may be linked into a dispenser slot.';
comment on column public.inventory_nodes.consumable_form is
  'Physical form for dispensable products (liquid, gel, …).';

-- Backfill: existing dispensers default to SINGLE.
update public.inventory_nodes
set dispenser_mode = 'SINGLE'
where is_dispenser = true and dispenser_mode is null;

create table if not exists public.dispenser_product_assignments (
  id uuid primary key default gen_random_uuid(),
  home_id uuid not null references public.homes (id) on delete cascade,
  dispenser_item_id uuid not null references public.inventory_nodes (id) on delete cascade,
  product_item_id uuid not null references public.inventory_nodes (id) on delete cascade,
  slot_number smallint not null check (slot_number between 1 and 3),
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default timezone('utc', now()),
  constraint dispenser_product_assignments_dispenser_slot_unique
    unique (dispenser_item_id, slot_number),
  constraint dispenser_product_assignments_dispenser_product_unique
    unique (dispenser_item_id, product_item_id),
  constraint dispenser_product_assignments_not_self
    check (dispenser_item_id <> product_item_id)
);

create index if not exists dispenser_product_assignments_home_idx
  on public.dispenser_product_assignments (home_id);
create index if not exists dispenser_product_assignments_product_idx
  on public.dispenser_product_assignments (product_item_id);

alter table public.dispenser_product_assignments enable row level security;

drop policy if exists dispenser_assignments_select on public.dispenser_product_assignments;
create policy dispenser_assignments_select
on public.dispenser_product_assignments for select
to authenticated
using (public.can_view_home(home_id));

drop policy if exists dispenser_assignments_insert on public.dispenser_product_assignments;
create policy dispenser_assignments_insert
on public.dispenser_product_assignments for insert
to authenticated
with check (public.can_edit_inventory(home_id));

drop policy if exists dispenser_assignments_update on public.dispenser_product_assignments;
create policy dispenser_assignments_update
on public.dispenser_product_assignments for update
to authenticated
using (public.can_edit_inventory(home_id))
with check (public.can_edit_inventory(home_id));

drop policy if exists dispenser_assignments_delete on public.dispenser_product_assignments;
create policy dispenser_assignments_delete
on public.dispenser_product_assignments for delete
to authenticated
using (public.can_edit_inventory(home_id));

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

  -- Clear existing occupant of this slot, then upsert product into slot.
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
    created_by
  ) values (
    v_disp.home_id,
    p_dispenser_item_id,
    p_product_item_id,
    p_slot_number,
    auth.uid()
  )
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.assign_product_to_dispenser(uuid, uuid, integer) from public;
grant execute on function public.assign_product_to_dispenser(uuid, uuid, integer) to authenticated;

create or replace function public.clear_dispenser_slot(
  p_dispenser_item_id uuid,
  p_slot_number integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_home uuid;
begin
  select home_id into v_home
  from public.inventory_nodes
  where id = p_dispenser_item_id;
  if v_home is null then
    raise exception 'dispenser not found' using errcode = 'P0002';
  end if;
  if not public.can_edit_inventory(v_home) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  delete from public.dispenser_product_assignments
  where dispenser_item_id = p_dispenser_item_id
    and slot_number = p_slot_number;
end;
$$;

revoke all on function public.clear_dispenser_slot(uuid, integer) from public;
grant execute on function public.clear_dispenser_slot(uuid, integer) to authenticated;
