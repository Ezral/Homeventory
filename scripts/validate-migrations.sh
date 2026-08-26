#!/usr/bin/env bash
# Validate Homeventory migrations against a local Postgres with an auth stub.
# Usage: ./scripts/validate-migrations.sh
# Does not require Docker / full Supabase stack.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB_NAME="${HOMEVENTORY_VALIDATE_DB:-homeventory_validate}"
PSQL=(sudo -u postgres psql -v ON_ERROR_STOP=1)

echo "==> Recreating database ${DB_NAME}"
sudo -u postgres psql -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS ${DB_NAME};"
sudo -u postgres psql -v ON_ERROR_STOP=1 -c "CREATE DATABASE ${DB_NAME};"

echo "==> Installing auth stub + roles"
"${PSQL[@]}" -d "${DB_NAME}" <<'SQL'
create extension if not exists pgcrypto;

create schema if not exists auth;

create table auth.users (
  id uuid primary key,
  aud text,
  role text,
  email text,
  encrypted_password text,
  email_confirmed_at timestamptz,
  raw_app_meta_data jsonb,
  raw_user_meta_data jsonb,
  created_at timestamptz,
  updated_at timestamptz
);

create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

create or replace function auth.jwt()
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'sub', current_setting('request.jwt.claim.sub', true),
    'role', current_setting('request.jwt.claim.role', true),
    'email', current_setting('request.jwt.claim.email', true)
  );
$$;

do $$ begin
  create role authenticated nologin;
exception when duplicate_object then null;
end $$;

do $$ begin
  create role anon nologin;
exception when duplicate_object then null;
end $$;

grant usage on schema public to authenticated;
grant usage on schema auth to authenticated;
SQL

echo "==> Applying migrations"
for migration in "${ROOT}"/supabase/migrations/*.sql; do
  echo "    $(basename "${migration}")"
  "${PSQL[@]}" -d "${DB_NAME}" -f "${migration}"
done

echo "==> Granting table privileges to authenticated (mirrors Supabase defaults)"
"${PSQL[@]}" -d "${DB_NAME}" <<'SQL'
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;
SQL

echo "==> Running smoke assertions"
"${PSQL[@]}" -d "${DB_NAME}" <<'SQL'
begin;

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'authenticated', 'authenticated',
    'alice@example.com', crypt('pw', gen_salt('bf')), now(),
    '{"provider":"google","providers":["google"]}', '{"full_name":"Alice"}',
    now(), now()
  ),
  (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'authenticated', 'authenticated',
    'bob@example.com', crypt('pw', gen_salt('bf')), now(),
    '{"provider":"google","providers":["google"]}', '{"full_name":"Bob"}',
    now(), now()
  );

do $$
begin
  if (select count(*) from public.profiles) <> 2 then
    raise exception 'expected 2 profiles from auth trigger, got %',
      (select count(*) from public.profiles);
  end if;
end $$;

select set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.email', 'alice@example.com', true);
set local role authenticated;

insert into public.homes (id, name, created_by_user_id)
values (
  '11111111-1111-1111-1111-111111111111',
  'Alice Home',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
);

do $$
declare
  owner_role text;
begin
  select role::text into owner_role
  from public.home_members
  where home_id = '11111111-1111-1111-1111-111111111111';
  if owner_role is distinct from 'OWNER' then
    raise exception 'creator should be OWNER, got %', owner_role;
  end if;
end $$;

insert into public.rooms (id, home_id, name, created_by_user_id)
values (
  '22222222-2222-2222-2222-222222222222',
  '11111111-1111-1111-1111-111111111111',
  'Kitchen',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
);

select public.create_invitation(
  '11111111-1111-1111-1111-111111111111',
  'EDITOR',
  'tokentokentokentokentokentokentoken12',
  'ABCD2345',
  null,
  72
);

reset role;
select set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.email', 'bob@example.com', true);
set local role authenticated;

do $$
declare
  member public.home_members%rowtype;
begin
  member := public.accept_invitation('ABCD2345');
  if member.user_id is distinct from 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid then
    raise exception 'short-code accept failed';
  end if;
  if member.role is distinct from 'EDITOR' then
    raise exception 'expected EDITOR role, got %', member.role;
  end if;
end $$;

reset role;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

do $$
declare
  member public.home_members%rowtype;
begin
  member := public.remove_home_member(
    '11111111-1111-1111-1111-111111111111',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
  );
  if member.status is distinct from 'REMOVED' then
    raise exception 'expected REMOVED status, got %', member.status;
  end if;
end $$;

reset role;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

insert into public.inventory_nodes (
  id, home_id, room_id, node_kind, name, is_container, created_by_user_id
) values (
  '44444444-4444-4444-4444-444444444444',
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  'ITEM',
  'Soap',
  false,
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
);

do $$
begin
  begin
    insert into public.reminders (
      home_id, created_by_user_id, kind, title, repeat, fire_minute, next_fire_at
    ) values (
      '11111111-1111-1111-1111-111111111111',
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'MANUAL',
      'No item',
      'ONCE',
      540,
      timezone('utc', now())
    );
    raise exception 'reminder without an item should fail';
  exception
    when check_violation then null;
  end;
end $$;

insert into public.reminders (
  id, home_id, created_by_user_id, kind, title, repeat, fire_minute, next_fire_at,
  inventory_node_id
) values (
  '33333333-3333-3333-3333-333333333333',
  '11111111-1111-1111-1111-111111111111',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'MANUAL',
  'Weekly Clean-up',
  'WEEKLY',
  540,
  timezone('utc', now()) + interval '7 days',
  '44444444-4444-4444-4444-444444444444'
);

insert into public.reminders (
  id, home_id, created_by_user_id, kind, title, repeat, fire_minute, next_fire_at,
  room_id
) values (
  '55555555-5555-5555-5555-555555555555',
  '11111111-1111-1111-1111-111111111111',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'MANUAL',
  'Kitchen wipe-down',
  'WEEKLY',
  540,
  timezone('utc', now()) + interval '7 days',
  '22222222-2222-2222-2222-222222222222'
);

do $$
begin
  begin
    insert into public.reminders (
      home_id, created_by_user_id, kind, title, repeat, fire_minute, next_fire_at,
      room_id
    ) values (
      '11111111-1111-1111-1111-111111111111',
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'USAGE_REFILL',
      'Refill kitchen',
      'ONCE',
      540,
      timezone('utc', now()),
      '22222222-2222-2222-2222-222222222222'
    );
    raise exception 'refill reminder on a room should fail';
  exception
    when check_violation then null;
  end;
end $$;

update public.reminders
set last_completed_at = timezone('utc', now()),
    next_fire_at = timezone('utc', now()) + interval '7 days'
where id = '33333333-3333-3333-3333-333333333333';

do $$
begin
  if (select count(*) from public.reminders
      where home_id = '11111111-1111-1111-1111-111111111111') <> 2 then
    raise exception 'owner should insert item and room reminders';
  end if;

  if not exists (
    select 1 from public.activity_events
    where home_id = '11111111-1111-1111-1111-111111111111'
      and action = 'CREATE_HOME'
  ) then
    raise exception 'creating a home should log activity';
  end if;
  if not exists (
    select 1 from public.activity_events
    where action = 'CREATE_ROOM'
  ) then
    raise exception 'creating a room should log activity';
  end if;
  if not exists (
    select 1 from public.activity_events
    where action = 'JOIN_HOME'
  ) then
    raise exception 'joining a home should log activity';
  end if;
  if not exists (
    select 1 from public.activity_events
    where action = 'CREATE_NODE'
  ) then
    raise exception 'adding an item should log activity';
  end if;
  if not exists (
    select 1 from public.activity_events
    where action = 'CREATE_SCHEDULE'
  ) then
    raise exception 'creating a schedule should log activity';
  end if;
  if not exists (
    select 1 from public.activity_events
    where action = 'COMPLETE_SCHEDULE'
  ) then
    raise exception 'completing a schedule should log activity';
  end if;
end $$;

do $$
begin
  begin
    insert into public.activity_events (home_id, action, summary)
    values (
      '11111111-1111-1111-1111-111111111111',
      'FORGED',
      'should not work'
    );
    raise exception 'authenticated must not insert activity_events';
  exception
    when insufficient_privilege then null;
  end;
end $$;

reset role;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

insert into public.homes (id, name, created_by_user_id)
values (
  'aaaaaaaa-0000-0000-0000-000000000001',
  'Delete Me',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
);

insert into public.rooms (id, home_id, name, created_by_user_id)
values (
  'aaaaaaaa-0000-0000-0000-000000000002',
  'aaaaaaaa-0000-0000-0000-000000000001',
  'Office',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
);

insert into public.inventory_nodes (
  id, home_id, room_id, node_kind, name, is_container, created_by_user_id
) values (
  'aaaaaaaa-0000-0000-0000-000000000003',
  'aaaaaaaa-0000-0000-0000-000000000001',
  'aaaaaaaa-0000-0000-0000-000000000002',
  'FURNITURE',
  'Desk',
  true,
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
);

insert into public.inventory_nodes (
  id, home_id, room_id, parent_node_id, node_kind, name, is_container, created_by_user_id
) values (
  'aaaaaaaa-0000-0000-0000-000000000004',
  'aaaaaaaa-0000-0000-0000-000000000001',
  'aaaaaaaa-0000-0000-0000-000000000002',
  'aaaaaaaa-0000-0000-0000-000000000003',
  'ITEM',
  'Notebook',
  false,
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
);

do $$
begin
  begin
    perform public.permanently_delete_archived_home(
      'aaaaaaaa-0000-0000-0000-000000000001'
    );
    raise exception 'active home should not be permanently deleted';
  exception
    when others then
      if SQLERRM not like '%must be archived%' then
        raise;
      end if;
  end;
end $$;

reset role;
select set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

do $$
begin
  begin
    perform public.permanently_delete_archived_home(
      'aaaaaaaa-0000-0000-0000-000000000001'
    );
    raise exception 'non-owner should not permanently delete a home';
  exception
    when others then
      if SQLERRM not like '%not authorized%' then
        raise;
      end if;
  end;
end $$;

reset role;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

update public.homes
set archived_at = timezone('utc', now())
where id = 'aaaaaaaa-0000-0000-0000-000000000001';

select public.permanently_delete_archived_home(
  'aaaaaaaa-0000-0000-0000-000000000001'
);

do $$
begin
  if exists (
    select 1 from public.homes where id = 'aaaaaaaa-0000-0000-0000-000000000001'
  ) then
    raise exception 'archived home should be gone after permanent delete';
  end if;
  if exists (
    select 1 from public.rooms where id = 'aaaaaaaa-0000-0000-0000-000000000002'
  ) then
    raise exception 'rooms of a permanently deleted home should be gone';
  end if;
  if exists (
    select 1 from public.inventory_nodes
    where home_id = 'aaaaaaaa-0000-0000-0000-000000000001'
  ) then
    raise exception 'inventory of a permanently deleted home should be gone';
  end if;
end $$;

reset role;
do $$ begin raise notice 'Smoke assertions passed'; end $$;
rollback;
SQL

echo "==> OK — migrations apply and smoke checks passed on ${DB_NAME}"
