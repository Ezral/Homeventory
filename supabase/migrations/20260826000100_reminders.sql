-- Home-scoped reminders: manual repeating alarms and usage-based refill alerts.
-- Source of truth is Postgres so web and Android share the same list.
-- Android schedules local notifications from these rows (no FCM yet).

create type public.reminder_kind as enum (
  'MANUAL',
  'USAGE_REFILL'
);

create type public.reminder_repeat as enum (
  'ONCE',
  'DAILY',
  'WEEKLY',
  'MONTHLY',
  'CUSTOM_DAYS'
);

create table public.reminders (
  id uuid primary key default gen_random_uuid(),
  home_id uuid not null references public.homes (id) on delete cascade,
  created_by_user_id uuid not null references public.profiles (id),
  kind public.reminder_kind not null,
  title text not null,
  body text,
  repeat public.reminder_repeat not null default 'ONCE',
  interval_days integer,
  fire_minute integer not null default 540,
  next_fire_at timestamptz not null,
  inventory_node_id uuid references public.inventory_nodes (id) on delete cascade,
  lead_days integer not null default 2,
  enabled boolean not null default true,
  last_notified_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint reminders_title_not_blank check (char_length(trim(title)) > 0),
  constraint reminders_fire_minute_range check (
    fire_minute >= 0 and fire_minute < 1440
  ),
  constraint reminders_lead_days_non_negative check (lead_days >= 0),
  constraint reminders_custom_interval check (
    repeat <> 'CUSTOM_DAYS' or interval_days >= 1
  ),
  constraint reminders_usage_needs_node check (
    kind <> 'USAGE_REFILL' or inventory_node_id is not null
  )
);

create index reminders_home_enabled_idx
  on public.reminders (home_id, enabled, next_fire_at);

comment on table public.reminders is
  'Manual alarms (custom title/repeat) and refill reminders tied to an inventory node.';

comment on column public.reminders.fire_minute is
  'Minutes from local midnight (0–1439) for the reminder clock time.';

alter table public.reminders enable row level security;

create policy reminders_select_member
on public.reminders for select
to authenticated
using (public.can_view_home(home_id));

create policy reminders_insert_editor
on public.reminders for insert
to authenticated
with check (
  public.can_edit_inventory(home_id)
  and created_by_user_id = auth.uid()
);

create policy reminders_update_editor
on public.reminders for update
to authenticated
using (public.can_edit_inventory(home_id))
with check (public.can_edit_inventory(home_id));

create policy reminders_delete_editor
on public.reminders for delete
to authenticated
using (public.can_edit_inventory(home_id));

grant select, insert, update, delete on public.reminders to authenticated;
