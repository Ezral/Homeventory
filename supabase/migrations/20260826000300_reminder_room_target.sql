-- Manual alarms may target a room or an inventory item. Refill still
-- requires an item (Use history lives on nodes).

alter table public.reminders
  alter column inventory_node_id drop not null;

alter table public.reminders
  add column if not exists room_id uuid references public.rooms (id) on delete cascade;

comment on column public.reminders.inventory_node_id is
  'Item or container this schedule is for. Null when the target is a room.';

comment on column public.reminders.room_id is
  'Room this schedule is for. Null when the target is an inventory item.';

alter table public.reminders
  drop constraint if exists reminders_one_target;

alter table public.reminders
  add constraint reminders_one_target check (
    (inventory_node_id is not null and room_id is null)
    or (inventory_node_id is null and room_id is not null)
  );

alter table public.reminders
  drop constraint if exists reminders_usage_needs_node;

alter table public.reminders
  add constraint reminders_usage_needs_node check (
    kind <> 'USAGE_REFILL' or inventory_node_id is not null
  );

create index if not exists reminders_room_id_idx
  on public.reminders (room_id)
  where room_id is not null;

create or replace function public.validate_reminder_target()
returns trigger
language plpgsql
as $$
declare
  target_home uuid;
begin
  if new.inventory_node_id is not null then
    select home_id into target_home
    from public.inventory_nodes
    where id = new.inventory_node_id;
    if target_home is distinct from new.home_id then
      raise exception 'linked item must belong to the same home';
    end if;
  end if;
  if new.room_id is not null then
    select home_id into target_home
    from public.rooms
    where id = new.room_id;
    if target_home is distinct from new.home_id then
      raise exception 'linked room must belong to the same home';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists reminders_validate_target on public.reminders;

create trigger reminders_validate_target
before insert or update on public.reminders
for each row execute function public.validate_reminder_target();
