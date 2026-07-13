-- Trips: luggage allowance + soft-delete (archive) for audit retention.

alter table public.trips
  add column if not exists luggage_allowance_kg numeric
    check (luggage_allowance_kg is null or luggage_allowance_kg >= 0),
  add column if not exists archived_at timestamptz;

comment on column public.trips.luggage_allowance_kg is
  'Airline / personal luggage weight limit in kilograms.';
comment on column public.trips.archived_at is
  'Soft-delete timestamp. Archived trips are hidden in the app but retained for audit.';

create index if not exists trips_home_active_idx
  on public.trips (home_id, created_at desc)
  where archived_at is null;
