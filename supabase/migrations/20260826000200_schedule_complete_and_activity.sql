-- Alarms must link to an inventory item. Completing a one-off archives it;
-- completing a repeating alarm advances next_fire_at.
-- Home activity_events is an append-only trail of membership and inventory
-- changes (create home, join, add/remove rooms and items, schedules).

alter table public.reminders
  add column if not exists archived_at timestamptz,
  add column if not exists last_completed_at timestamptz;

delete from public.reminders
where inventory_node_id is null;

alter table public.reminders
  alter column inventory_node_id set not null;

alter table public.reminders
  drop constraint if exists reminders_usage_needs_node;

comment on column public.reminders.inventory_node_id is
  'Every alarm and refill reminder is tied to one inventory node.';

comment on column public.reminders.archived_at is
  'Set when a one-off schedule is completed. Hidden from the active list.';

comment on column public.reminders.last_completed_at is
  'Last time a member marked this schedule done.';

create index if not exists reminders_home_active_idx
  on public.reminders (home_id, next_fire_at)
  where archived_at is null and enabled = true;

-- ---------------------------------------------------------------------------
-- activity_events
-- ---------------------------------------------------------------------------

create table public.activity_events (
  id uuid primary key default gen_random_uuid(),
  home_id uuid not null references public.homes (id) on delete cascade,
  actor_user_id uuid references public.profiles (id),
  action text not null,
  entity_type text,
  entity_id uuid,
  summary text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index activity_events_home_created_idx
  on public.activity_events (home_id, created_at desc);

comment on table public.activity_events is
  'Append-only household activity: membership, rooms, inventory, and schedules.';

alter table public.activity_events enable row level security;

create policy activity_events_select_member
on public.activity_events for select
to authenticated
using (public.can_view_home(home_id));

grant select on public.activity_events to authenticated;

create or replace function public.activity_actor_label(p_user_id uuid)
returns text
language sql
stable
set search_path = public
as $$
  select coalesce(
    nullif(trim(p.display_name), ''),
    nullif(split_part(coalesce(p.email, ''), '@', 1), ''),
    'Someone'
  )
  from public.profiles p
  where p.id = p_user_id;
$$;

create or replace function public.log_home_activity(
  p_home_id uuid,
  p_action text,
  p_summary text,
  p_entity_type text default null,
  p_entity_id uuid default null,
  p_metadata jsonb default '{}'::jsonb,
  p_actor_user_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid;
begin
  if p_home_id is null or p_summary is null or char_length(trim(p_summary)) = 0 then
    return;
  end if;
  actor := coalesce(p_actor_user_id, auth.uid());
  insert into public.activity_events (
    home_id,
    actor_user_id,
    action,
    entity_type,
    entity_id,
    summary,
    metadata
  ) values (
    p_home_id,
    actor,
    p_action,
    p_entity_type,
    p_entity_id,
    trim(p_summary),
    coalesce(p_metadata, '{}'::jsonb)
  );
end;
$$;

revoke all on function public.log_home_activity(
  uuid, text, text, text, uuid, jsonb, uuid
) from public, anon, authenticated;

-- Homes
create or replace function public.activity_on_homes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.log_home_activity(
      new.id,
      'CREATE_HOME',
      coalesce(public.activity_actor_label(new.created_by_user_id), 'Someone')
        || ' created ' || new.name,
      'HOME',
      new.id,
      jsonb_build_object('name', new.name),
      new.created_by_user_id
    );
  elsif tg_op = 'UPDATE' then
    if new.archived_at is not null and old.archived_at is null then
      perform public.log_home_activity(
        new.id,
        'ARCHIVE_HOME',
        coalesce(public.activity_actor_label(auth.uid()), 'Someone')
          || ' archived ' || new.name,
        'HOME',
        new.id
      );
    elsif new.name is distinct from old.name then
      perform public.log_home_activity(
        new.id,
        'UPDATE_HOME',
        coalesce(public.activity_actor_label(auth.uid()), 'Someone')
          || ' renamed the home to ' || new.name,
        'HOME',
        new.id,
        jsonb_build_object('from', old.name, 'to', new.name)
      );
    end if;
  end if;
  return coalesce(new, old);
end;
$$;

create trigger activity_homes
after insert or update on public.homes
for each row execute function public.activity_on_homes();

-- Membership (skip the automatic OWNER row created with the home)
create or replace function public.activity_on_home_members()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor text;
  member_name text;
begin
  if tg_op = 'INSERT' then
    if new.role = 'OWNER' and exists (
      select 1 from public.homes h
      where h.id = new.home_id and h.created_by_user_id = new.user_id
    ) then
      return new;
    end if;
    member_name := coalesce(public.activity_actor_label(new.user_id), 'Someone');
    perform public.log_home_activity(
      new.home_id,
      'JOIN_HOME',
      member_name || ' joined',
      'MEMBER',
      new.id,
      jsonb_build_object('role', new.role::text),
      new.user_id
    );
  elsif tg_op = 'UPDATE' then
    if new.status = 'REMOVED' and old.status is distinct from 'REMOVED' then
      actor := coalesce(public.activity_actor_label(auth.uid()), 'Someone');
      member_name := coalesce(public.activity_actor_label(new.user_id), 'a member');
      perform public.log_home_activity(
        new.home_id,
        'REMOVE_MEMBER',
        actor || ' removed ' || member_name,
        'MEMBER',
        new.id,
        jsonb_build_object('user_id', new.user_id)
      );
    end if;
  end if;
  return coalesce(new, old);
end;
$$;

create trigger activity_home_members
after insert or update on public.home_members
for each row execute function public.activity_on_home_members();

-- Invitations
create or replace function public.activity_on_invitations()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.log_home_activity(
      new.home_id,
      'INVITE_MEMBER',
      coalesce(public.activity_actor_label(new.created_by_user_id), 'Someone')
        || ' invited a ' || lower(new.role::text),
      'INVITATION',
      new.id,
      jsonb_build_object('role', new.role::text),
      new.created_by_user_id
    );
  end if;
  return new;
end;
$$;

create trigger activity_invitations
after insert on public.invitations
for each row execute function public.activity_on_invitations();

-- Rooms
create or replace function public.activity_on_rooms()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.log_home_activity(
      new.home_id,
      'CREATE_ROOM',
      coalesce(public.activity_actor_label(new.created_by_user_id), 'Someone')
        || ' added room ' || new.name,
      'ROOM',
      new.id,
      jsonb_build_object('name', new.name),
      new.created_by_user_id
    );
  elsif tg_op = 'UPDATE' then
    if new.archived_at is not null and old.archived_at is null then
      perform public.log_home_activity(
        new.home_id,
        'ARCHIVE_ROOM',
        coalesce(public.activity_actor_label(auth.uid()), 'Someone')
          || ' archived room ' || new.name,
        'ROOM',
        new.id
      );
    elsif new.name is distinct from old.name then
      perform public.log_home_activity(
        new.home_id,
        'UPDATE_ROOM',
        coalesce(public.activity_actor_label(auth.uid()), 'Someone')
          || ' renamed a room to ' || new.name,
        'ROOM',
        new.id,
        jsonb_build_object('from', old.name, 'to', new.name)
      );
    end if;
  elsif tg_op = 'DELETE' then
    perform public.log_home_activity(
      old.home_id,
      'DELETE_ROOM',
      coalesce(public.activity_actor_label(auth.uid()), 'Someone')
        || ' removed room ' || old.name,
      'ROOM',
      old.id,
      jsonb_build_object('name', old.name)
    );
  end if;
  return coalesce(new, old);
end;
$$;

create trigger activity_rooms
after insert or update or delete on public.rooms
for each row execute function public.activity_on_rooms();

-- Inventory
create or replace function public.activity_on_inventory_nodes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.log_home_activity(
      new.home_id,
      'CREATE_NODE',
      coalesce(public.activity_actor_label(new.created_by_user_id), 'Someone')
        || ' added ' || new.name,
      'INVENTORY_NODE',
      new.id,
      jsonb_build_object('name', new.name, 'kind', new.node_kind::text),
      new.created_by_user_id
    );
  elsif tg_op = 'UPDATE' then
    if new.is_disposed and not old.is_disposed then
      perform public.log_home_activity(
        new.home_id,
        'DISPOSE_NODE',
        coalesce(public.activity_actor_label(auth.uid()), 'Someone')
          || ' disposed ' || new.name,
        'INVENTORY_NODE',
        new.id
      );
    elsif new.archived_at is not null and old.archived_at is null then
      perform public.log_home_activity(
        new.home_id,
        'ARCHIVE_NODE',
        coalesce(public.activity_actor_label(auth.uid()), 'Someone')
          || ' archived ' || new.name,
        'INVENTORY_NODE',
        new.id
      );
    elsif new.room_id is distinct from old.room_id
      or new.parent_node_id is distinct from old.parent_node_id then
      perform public.log_home_activity(
        new.home_id,
        'MOVE_NODE',
        coalesce(public.activity_actor_label(auth.uid()), 'Someone')
          || ' moved ' || new.name,
        'INVENTORY_NODE',
        new.id
      );
    elsif new.name is distinct from old.name then
      perform public.log_home_activity(
        new.home_id,
        'UPDATE_NODE',
        coalesce(public.activity_actor_label(auth.uid()), 'Someone')
          || ' renamed an item to ' || new.name,
        'INVENTORY_NODE',
        new.id,
        jsonb_build_object('from', old.name, 'to', new.name)
      );
    end if;
  elsif tg_op = 'DELETE' then
    perform public.log_home_activity(
      old.home_id,
      'DELETE_NODE',
      coalesce(public.activity_actor_label(auth.uid()), 'Someone')
        || ' removed ' || old.name,
      'INVENTORY_NODE',
      old.id,
      jsonb_build_object('name', old.name)
    );
  end if;
  return coalesce(new, old);
end;
$$;

create trigger activity_inventory_nodes
after insert or update or delete on public.inventory_nodes
for each row execute function public.activity_on_inventory_nodes();

-- Schedules
create or replace function public.activity_on_reminders()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.log_home_activity(
      new.home_id,
      'CREATE_SCHEDULE',
      coalesce(public.activity_actor_label(new.created_by_user_id), 'Someone')
        || ' scheduled ' || new.title,
      'REMINDER',
      new.id,
      jsonb_build_object('title', new.title),
      new.created_by_user_id
    );
  elsif tg_op = 'UPDATE' then
    if new.last_completed_at is distinct from old.last_completed_at then
      perform public.log_home_activity(
        new.home_id,
        'COMPLETE_SCHEDULE',
        coalesce(public.activity_actor_label(auth.uid()), 'Someone')
          || ' completed ' || new.title,
        'REMINDER',
        new.id,
        jsonb_build_object(
          'archived', new.archived_at is not null,
          'next_fire_at', new.next_fire_at
        )
      );
    end if;
  elsif tg_op = 'DELETE' then
    perform public.log_home_activity(
      old.home_id,
      'DELETE_SCHEDULE',
      coalesce(public.activity_actor_label(auth.uid()), 'Someone')
        || ' removed schedule ' || old.title,
      'REMINDER',
      old.id,
      jsonb_build_object('title', old.title)
    );
  end if;
  return coalesce(new, old);
end;
$$;

create trigger activity_reminders
after insert or update or delete on public.reminders
for each row execute function public.activity_on_reminders();
