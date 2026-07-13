-- Phase A–C: home profile fields + dashboard aggregate RPC.

alter table public.homes
  add column if not exists residing_since date,
  add column if not exists remarks text,
  add column if not exists updated_by uuid references public.profiles (id);

comment on column public.homes.residing_since is
  'Date the household began residing; residence duration is derived, never stored.';
comment on column public.homes.remarks is
  'Optional multiline household notes (separate from short description).';
comment on column public.homes.updated_by is
  'Last user who updated the home profile.';

create or replace function public.touch_home_updated_by()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_by := auth.uid();
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists homes_touch_updated_by on public.homes;
create trigger homes_touch_updated_by
before update on public.homes
for each row
execute function public.touch_home_updated_by();

-- Dashboard aggregates for the current member (privacy filtering comes in Phase G).
create or replace function public.home_dashboard_stats(p_home_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_currency text;
  v_rooms integer;
  v_furniture integer;
  v_members integer;
  v_value numeric;
begin
  if not public.can_view_home(p_home_id) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  select default_currency into v_currency
  from public.homes
  where id = p_home_id and archived_at is null;

  if v_currency is null then
    raise exception 'home not found' using errcode = 'P0002';
  end if;

  select count(*)::integer into v_rooms
  from public.rooms
  where home_id = p_home_id and archived_at is null;

  select count(*)::integer into v_furniture
  from public.inventory_nodes
  where home_id = p_home_id
    and archived_at is null
    and coalesce(is_disposed, false) = false
    and parent_node_id is null
    and node_kind = 'FURNITURE';

  select count(*)::integer into v_members
  from public.home_members
  where home_id = p_home_id and status = 'ACTIVE';

  -- Phase C stub: sum prices already in home currency (or null currency).
  -- Mixed-currency conversion is Phase I.
  select coalesce(sum(purchase_price), 0) into v_value
  from public.inventory_nodes
  where home_id = p_home_id
    and archived_at is null
    and coalesce(is_disposed, false) = false
    and purchase_price is not null
    and (
      currency is null
      or upper(currency) = upper(v_currency)
    );

  return jsonb_build_object(
    'rooms_count', v_rooms,
    'base_furniture_count', v_furniture,
    'members_count', v_members,
    'estimated_value', v_value,
    'value_currency', v_currency,
    'value_is_partial', true
  );
end;
$$;

revoke all on function public.home_dashboard_stats(uuid) from public;
grant execute on function public.home_dashboard_stats(uuid) to authenticated;
