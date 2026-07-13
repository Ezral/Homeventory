-- Dashboard: show in-house item count instead of members on home cards.

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
  v_items integer;
  v_members integer;
  v_value numeric := 0;
  v_unconverted_count integer := 0;
  v_converted_count integer := 0;
  v_rate_date date;
  v_oldest_retrieved timestamptz;
  v_any_stale boolean := false;
  r record;
  v_converted numeric;
  v_from text;
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
  v_currency := upper(v_currency);

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

  -- Active items currently in the home (not disposed / archived).
  select count(*)::integer into v_items
  from public.inventory_nodes
  where home_id = p_home_id
    and archived_at is null
    and coalesce(is_disposed, false) = false
    and node_kind = 'ITEM';

  select count(*)::integer into v_members
  from public.home_members
  where home_id = p_home_id and status = 'ACTIVE';

  for r in
    select
      coalesce(nullif(upper(trim(n.currency)), ''), v_currency) as src_currency,
      sum(n.purchase_price) as subtotal,
      count(*)::integer as item_count
    from public.inventory_nodes n
    where n.home_id = p_home_id
      and n.archived_at is null
      and coalesce(n.is_disposed, false) = false
      and n.purchase_price is not null
    group by 1
  loop
    v_from := r.src_currency;
    v_converted := public.convert_currency_amount(r.subtotal, v_from, v_currency);
    if v_converted is null then
      v_unconverted_count := v_unconverted_count + r.item_count;
    else
      v_value := v_value + v_converted;
      v_converted_count := v_converted_count + r.item_count;
    end if;
  end loop;

  select
    max(er.rate_date),
    min(er.retrieved_at),
    bool_or(er.expires_at < timezone('utc', now()))
  into v_rate_date, v_oldest_retrieved, v_any_stale
  from public.exchange_rates er
  where er.quote_currency = v_currency
     or er.base_currency = v_currency;

  return jsonb_build_object(
    'rooms_count', v_rooms,
    'base_furniture_count', v_furniture,
    'items_count', v_items,
    'members_count', v_members,
    'estimated_value', round(v_value, 2),
    'value_currency', v_currency,
    'value_is_partial', v_unconverted_count > 0,
    'unconverted_item_count', v_unconverted_count,
    'converted_item_count', v_converted_count,
    'rate_date', v_rate_date,
    'rates_retrieved_at', v_oldest_retrieved,
    'rates_stale', coalesce(v_any_stale, false),
    'fx_provider', 'frankfurter'
  );
end;
$$;

revoke all on function public.home_dashboard_stats(uuid) from public;
grant execute on function public.home_dashboard_stats(uuid) to authenticated;
