-- Phase 4–5: images + barcodes, storage bucket, grants

-- ---------------------------------------------------------------------------
-- images
-- ---------------------------------------------------------------------------

create table public.images (
  id uuid primary key default gen_random_uuid(),
  home_id uuid not null references public.homes (id) on delete cascade,
  entity_type text not null check (
    entity_type in ('HOME', 'ROOM', 'INVENTORY_NODE')
  ),
  entity_id uuid not null,
  storage_path text not null,
  thumbnail_path text,
  mime_type text,
  width integer,
  height integer,
  file_size integer,
  uploaded_by_user_id uuid not null references public.profiles (id),
  created_at timestamptz not null default timezone('utc', now())
);

create index images_home_id_idx on public.images (home_id);
create index images_entity_idx on public.images (entity_type, entity_id);

alter table public.images enable row level security;

create policy images_select_member
on public.images for select
to authenticated
using (public.can_view_home(home_id));

create policy images_insert_editor
on public.images for insert
to authenticated
with check (
  public.can_edit_inventory(home_id)
  and uploaded_by_user_id = auth.uid()
);

create policy images_update_editor
on public.images for update
to authenticated
using (public.can_edit_inventory(home_id))
with check (public.can_edit_inventory(home_id));

create policy images_delete_editor
on public.images for delete
to authenticated
using (public.can_edit_inventory(home_id));

-- ---------------------------------------------------------------------------
-- item_barcodes
-- ---------------------------------------------------------------------------

create table public.item_barcodes (
  id uuid primary key default gen_random_uuid(),
  home_id uuid not null references public.homes (id) on delete cascade,
  inventory_node_id uuid not null references public.inventory_nodes (id) on delete cascade,
  barcode_value text not null,
  barcode_format text,
  is_primary boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  unique (home_id, barcode_value)
);

create index item_barcodes_node_idx on public.item_barcodes (inventory_node_id);
create index item_barcodes_value_idx on public.item_barcodes (home_id, barcode_value);

alter table public.item_barcodes enable row level security;

create policy item_barcodes_select_member
on public.item_barcodes for select
to authenticated
using (public.can_view_home(home_id));

create policy item_barcodes_insert_editor
on public.item_barcodes for insert
to authenticated
with check (public.can_edit_inventory(home_id));

create policy item_barcodes_update_editor
on public.item_barcodes for update
to authenticated
using (public.can_edit_inventory(home_id))
with check (public.can_edit_inventory(home_id));

create policy item_barcodes_delete_editor
on public.item_barcodes for delete
to authenticated
using (public.can_edit_inventory(home_id));

-- ---------------------------------------------------------------------------
-- Private storage bucket for images
-- Path convention: {home_id}/{entity_type}/{entity_id}/{filename}
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'home-images',
  'home-images',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
on conflict (id) do nothing;

create or replace function public.storage_home_id(object_name text)
returns uuid
language plpgsql
immutable
as $$
declare
  part text := split_part(object_name, '/', 1);
begin
  if part ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return part::uuid;
  end if;
  return null;
end;
$$;

drop policy if exists home_images_select_member on storage.objects;
create policy home_images_select_member
on storage.objects for select
to authenticated
using (
  bucket_id = 'home-images'
  and public.storage_home_id(name) is not null
  and public.can_view_home(public.storage_home_id(name))
);

drop policy if exists home_images_insert_editor on storage.objects;
create policy home_images_insert_editor
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'home-images'
  and public.storage_home_id(name) is not null
  and public.can_edit_inventory(public.storage_home_id(name))
);

drop policy if exists home_images_update_editor on storage.objects;
create policy home_images_update_editor
on storage.objects for update
to authenticated
using (
  bucket_id = 'home-images'
  and public.storage_home_id(name) is not null
  and public.can_edit_inventory(public.storage_home_id(name))
)
with check (
  bucket_id = 'home-images'
  and public.storage_home_id(name) is not null
  and public.can_edit_inventory(public.storage_home_id(name))
);

drop policy if exists home_images_delete_editor on storage.objects;
create policy home_images_delete_editor
on storage.objects for delete
to authenticated
using (
  bucket_id = 'home-images'
  and public.storage_home_id(name) is not null
  and public.can_edit_inventory(public.storage_home_id(name))
);

grant select, insert, update, delete on public.images to authenticated;
grant select, insert, update, delete on public.item_barcodes to authenticated;
