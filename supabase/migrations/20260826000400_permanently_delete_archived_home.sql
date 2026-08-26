-- Permanent delete of archived homes (owner-only).
--
-- Direct DELETE FROM homes is not enough: child FKs are mixed cascade /
-- no-action, inventory_transactions and activity_events deny client
-- deletes, and storage objects would be orphaned. This RPC is the only
-- supported hard-delete path.

-- ---------------------------------------------------------------------------
-- Client DELETE on homes is closed; use the RPC below.
-- ---------------------------------------------------------------------------

drop policy if exists homes_delete_owner on public.homes;

-- ---------------------------------------------------------------------------
-- permanently_delete_archived_home
-- ---------------------------------------------------------------------------

create or replace function public.permanently_delete_archived_home(p_home_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  home_rec public.homes%rowtype;
  v_deleted integer;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;
  if p_home_id is null then
    raise exception 'home id is required';
  end if;
  if not public.can_admin_home(p_home_id) then
    raise exception 'not authorized to delete this home';
  end if;

  select * into home_rec
  from public.homes
  where id = p_home_id
  for update;

  if home_rec.id is null then
    raise exception 'home not found';
  end if;
  if home_rec.archived_at is null then
    raise exception 'home must be archived before it can be permanently deleted';
  end if;

  -- Private images live under {home_id}/… ; skip when Storage is not present
  -- (local migration validation stubs auth only).
  if to_regclass('storage.objects') is not null then
    execute
      'delete from storage.objects
       where bucket_id = $1
         and name like $2'
      using 'home-images', p_home_id::text || '/%';
  end if;

  -- Rows that block inventory_nodes / rooms (no ON DELETE CASCADE).
  delete from public.inventory_transactions where home_id = p_home_id;
  delete from public.trip_items where home_id = p_home_id;
  delete from public.trip_containers where home_id = p_home_id;
  delete from public.dispenser_product_assignments where home_id = p_home_id;
  delete from public.reminders where home_id = p_home_id;
  delete from public.item_barcodes where home_id = p_home_id;
  delete from public.images where home_id = p_home_id;

  -- parent_node_id is self-referential without cascade: delete leaves first.
  loop
    delete from public.inventory_nodes n
    where n.home_id = p_home_id
      and not exists (
        select 1
        from public.inventory_nodes c
        where c.parent_node_id = n.id
      );
    get diagnostics v_deleted = row_count;
    exit when v_deleted = 0;
  end loop;

  -- Cycle leftover (should not exist); break the self-FK then drop.
  update public.inventory_nodes
  set parent_node_id = null
  where home_id = p_home_id
    and parent_node_id is not null;
  delete from public.inventory_nodes where home_id = p_home_id;

  delete from public.rooms where home_id = p_home_id;
  delete from public.trips where home_id = p_home_id;

  -- Cascades remaining membership, invitations, and activity.
  delete from public.homes where id = p_home_id;
end;
$$;

comment on function public.permanently_delete_archived_home(uuid) is
  'OWNER-only hard delete of an archived home: inventory, rooms, trips, images, and storage objects.';

revoke all on function public.permanently_delete_archived_home(uuid) from public;
grant execute on function public.permanently_delete_archived_home(uuid) to authenticated;
