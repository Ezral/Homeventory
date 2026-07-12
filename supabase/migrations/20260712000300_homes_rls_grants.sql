-- Fix client access to Phase 1–3 tables and home create RETURNING.
--
-- Hosted Supabase migrations do not always inherit dashboard default grants.
-- Also: PostgREST .insert().select() requires a SELECT policy that matches the
-- new row; allow creators to read homes they own even before membership checks.

-- ---------------------------------------------------------------------------
-- Privileges
-- ---------------------------------------------------------------------------

grant usage on schema public to anon, authenticated;

grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

alter default privileges in schema public
  grant select, insert, update, delete on tables to authenticated;

alter default privileges in schema public
  grant usage, select on sequences to authenticated;

-- ---------------------------------------------------------------------------
-- homes: creator can select their own rows (covers INSERT ... RETURNING)
-- ---------------------------------------------------------------------------

drop policy if exists homes_select_creator on public.homes;

create policy homes_select_creator
on public.homes for select
to authenticated
using (created_by_user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Ensure auth → profile works for OAuth users (idempotent)
-- ---------------------------------------------------------------------------

-- Re-assert profile auto-create trigger exists (no-op if already present).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name, avatar_url)
  values (
    new.id,
    new.email,
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      split_part(coalesce(new.email, 'user'), '@', 1)
    ),
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do update
  set
    email = excluded.email,
    display_name = coalesce(public.profiles.display_name, excluded.display_name),
    avatar_url = coalesce(public.profiles.avatar_url, excluded.avatar_url),
    updated_at = timezone('utc', now());
  return new;
end;
$$;

-- Backfill profiles for any auth users missing one (e.g. signed in before grants).
insert into public.profiles (id, email, display_name, avatar_url)
select
  u.id,
  u.email,
  coalesce(
    u.raw_user_meta_data ->> 'full_name',
    u.raw_user_meta_data ->> 'name',
    split_part(coalesce(u.email, 'user'), '@', 1)
  ),
  u.raw_user_meta_data ->> 'avatar_url'
from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id)
on conflict (id) do nothing;
