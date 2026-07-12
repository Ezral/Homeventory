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
do $$ begin raise notice 'Smoke assertions passed'; end $$;
rollback;
SQL

echo "==> OK — migrations apply and smoke checks passed on ${DB_NAME}"
