-- Cross-Home authorization smoke tests (pgTAP).
-- Run with: supabase test db
-- These tests assert that membership is required and UUID guessing fails.

begin;
select plan(8);

create extension if not exists pgtap;

-- Synthetic users (auth.users + profiles)
insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'authenticated', 'authenticated', 'alice@example.com', crypt('pw', gen_salt('bf')), now(), '{"provider":"google","providers":["google"]}', '{"full_name":"Alice"}', now(), now()),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'authenticated', 'authenticated', 'bob@example.com', crypt('pw', gen_salt('bf')), now(), '{"provider":"google","providers":["google"]}', '{"full_name":"Bob"}', now(), now());

-- Profiles are created by trigger; assert that.
select is(
  (select count(*)::int from public.profiles where id in (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
  )),
  2,
  'auth users receive profiles'
);

-- Alice creates Home A as herself
select set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

set local role authenticated;

insert into public.homes (id, name, created_by_user_id)
values ('11111111-1111-1111-1111-111111111111', 'Alice Home', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

select is(
  (select role::text from public.home_members where home_id = '11111111-1111-1111-1111-111111111111'),
  'OWNER',
  'home creator becomes OWNER'
);

select is(
  (select count(*)::int from public.homes where id = '11111111-1111-1111-1111-111111111111'),
  1,
  'owner can select own home'
);

reset role;

-- Bob cannot see Alice's home by UUID
select set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

select is(
  (select count(*)::int from public.homes where id = '11111111-1111-1111-1111-111111111111'),
  0,
  'non-member cannot select another home by UUID'
);

select throws_ok(
  $$insert into public.rooms (home_id, name, created_by_user_id)
    values ('11111111-1111-1111-1111-111111111111', 'Hacked Room', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')$$,
  '42501',
  null,
  'non-member cannot insert room into another home'
);

reset role;

-- Alice adds a room and inventory; Bob still blocked
select set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

insert into public.rooms (id, home_id, name, created_by_user_id)
values (
  '22222222-2222-2222-2222-222222222222',
  '11111111-1111-1111-1111-111111111111',
  'Kitchen',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
);

insert into public.inventory_nodes (
  id, home_id, room_id, node_kind, name, is_container, created_by_user_id
) values (
  '33333333-3333-3333-3333-333333333333',
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  'FURNITURE',
  'Cabinet',
  true,
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
);

select is(
  (select count(*)::int from public.inventory_nodes where id = '33333333-3333-3333-3333-333333333333'),
  1,
  'member can create inventory nodes'
);

reset role;

select set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

select is(
  (select count(*)::int from public.inventory_nodes where id = '33333333-3333-3333-3333-333333333333'),
  0,
  'non-member cannot read inventory by UUID'
);

reset role;

-- Cycle prevention via move_inventory_node
select set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

insert into public.inventory_nodes (
  id, home_id, room_id, parent_node_id, node_kind, name, is_container, is_mobile_container, item_category, created_by_user_id
) values (
  '44444444-4444-4444-4444-444444444444',
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333',
  'ITEM',
  'Suitcase',
  true,
  true,
  'BAG_LUGGAGE',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
);

select throws_ok(
  $$select public.move_inventory_node(
    '33333333-3333-3333-3333-333333333333',
    '22222222-2222-2222-2222-222222222222',
    '44444444-4444-4444-4444-444444444444'
  )$$,
  null,
  'cyclic containment is not allowed',
  'moving a node into its descendant is rejected'
);

select * from finish();
rollback;
