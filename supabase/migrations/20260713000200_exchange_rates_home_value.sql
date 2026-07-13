-- Home-currency dashboard valuation via cached FX rates (Frankfurter / ECB).

create table if not exists public.exchange_rates (
  id uuid primary key default gen_random_uuid(),
  base_currency text not null,
  quote_currency text not null,
  rate numeric not null check (rate > 0),
  rate_date date not null,
  provider text not null default 'frankfurter',
  retrieved_at timestamptz not null default timezone('utc', now()),
  expires_at timestamptz not null,
  constraint exchange_rates_pair_provider_unique
    unique (base_currency, quote_currency, provider),
  constraint exchange_rates_currencies_upper
    check (
      base_currency = upper(base_currency)
      and quote_currency = upper(quote_currency)
      and char_length(base_currency) between 3 and 3
      and char_length(quote_currency) between 3 and 3
    )
);

create index if not exists exchange_rates_pair_idx
  on public.exchange_rates (base_currency, quote_currency);

comment on table public.exchange_rates is
  'Cached FX rates. rate means 1 base_currency = rate quote_currency. Source of truth for conversion; providers are swappable.';

alter table public.exchange_rates enable row level security;

drop policy if exists exchange_rates_select_authenticated on public.exchange_rates;
create policy exchange_rates_select_authenticated
on public.exchange_rates for select
to authenticated
using (true);

-- Clients refresh public FX data via RPC (no direct insert policy).
create or replace function public.upsert_exchange_rate(
  p_base_currency text,
  p_quote_currency text,
  p_rate numeric,
  p_rate_date date,
  p_provider text default 'frankfurter',
  p_expires_at timestamptz default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_base text := upper(trim(p_base_currency));
  v_quote text := upper(trim(p_quote_currency));
  v_expires timestamptz := coalesce(
    p_expires_at,
    timezone('utc', now()) + interval '24 hours'
  );
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if v_base is null or v_quote is null or v_base = v_quote then
    return;
  end if;
  if p_rate is null or p_rate <= 0 then
    raise exception 'rate must be positive' using errcode = '22023';
  end if;

  insert into public.exchange_rates as er (
    base_currency,
    quote_currency,
    rate,
    rate_date,
    provider,
    retrieved_at,
    expires_at
  ) values (
    v_base,
    v_quote,
    p_rate,
    p_rate_date,
    coalesce(nullif(trim(p_provider), ''), 'frankfurter'),
    timezone('utc', now()),
    v_expires
  )
  on conflict (base_currency, quote_currency, provider)
  do update set
    rate = excluded.rate,
    rate_date = excluded.rate_date,
    retrieved_at = excluded.retrieved_at,
    expires_at = excluded.expires_at;
end;
$$;

revoke all on function public.upsert_exchange_rate(text, text, numeric, date, text, timestamptz)
  from public;
grant execute on function public.upsert_exchange_rate(text, text, numeric, date, text, timestamptz)
  to authenticated;

-- Convert amount using latest cached pair, or inverse pair.
create or replace function public.convert_currency_amount(
  p_amount numeric,
  p_from_currency text,
  p_to_currency text
)
returns numeric
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  v_from text := upper(trim(p_from_currency));
  v_to text := upper(trim(p_to_currency));
  v_rate numeric;
begin
  if p_amount is null then
    return null;
  end if;
  if v_from is null or v_from = '' then
    v_from := v_to;
  end if;
  if v_from = v_to then
    return p_amount;
  end if;

  select er.rate into v_rate
  from public.exchange_rates er
  where er.base_currency = v_from
    and er.quote_currency = v_to
  order by er.rate_date desc, er.retrieved_at desc
  limit 1;

  if v_rate is not null then
    return p_amount * v_rate;
  end if;

  select er.rate into v_rate
  from public.exchange_rates er
  where er.base_currency = v_to
    and er.quote_currency = v_from
  order by er.rate_date desc, er.retrieved_at desc
  limit 1;

  if v_rate is not null and v_rate <> 0 then
    return p_amount / v_rate;
  end if;

  return null;
end;
$$;

revoke all on function public.convert_currency_amount(numeric, text, text) from public;
grant execute on function public.convert_currency_amount(numeric, text, text) to authenticated;

-- Distinct item currencies that need rates for a home (excluding home currency / blanks).
create or replace function public.home_item_currencies(p_home_id uuid)
returns text[]
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_home text;
  v_list text[];
begin
  if not public.can_view_home(p_home_id) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  select upper(default_currency) into v_home
  from public.homes
  where id = p_home_id and archived_at is null;

  if v_home is null then
    raise exception 'home not found' using errcode = 'P0002';
  end if;

  select coalesce(array_agg(distinct upper(n.currency) order by upper(n.currency)), '{}')
  into v_list
  from public.inventory_nodes n
  where n.home_id = p_home_id
    and n.archived_at is null
    and coalesce(n.is_disposed, false) = false
    and n.purchase_price is not null
    and n.currency is not null
    and length(trim(n.currency)) > 0
    and upper(n.currency) <> v_home;

  return v_list;
end;
$$;

revoke all on function public.home_item_currencies(uuid) from public;
grant execute on function public.home_item_currencies(uuid) to authenticated;

-- Dashboard: convert every priced item into the home currency, then sum.
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

  select count(*)::integer into v_members
  from public.home_members
  where home_id = p_home_id and status = 'ACTIVE';

  -- Aggregate by source currency first, then convert each subtotal once.
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
