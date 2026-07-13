# ADR-0005

Unified recursive inventory nodes

## Status

Accepted

## Date

2026-07-12

---

## Context

Households store things in rooms, furniture, drawers, boxes, and bags. Nesting depth is unbounded. Some items (suitcases) are both countable belongings and containers. Separate rigid tables per level break real layouts and complicate moves.

---

## Decision

All placeable inventory objects live in one table: **`inventory_nodes`**.

Kinds (`inventory_node_kind`):

- `FURNITURE`
- `STORAGE_LOCATION`
- `ITEM`

Containment:

- Optional `parent_node_id` self-FK.
- `is_container` / `is_mobile_container` flags (mobile implies container).
- Items may be containers.
- Every node has `home_id` and `room_id` denormalized for RLS and room-scoped queries.
- Nested inserts inherit the parent’s `room_id` via trigger `validate_inventory_node`.

Integrity today:

- Parent must exist, same home, be a container, and not be archived.
- Room must belong to the same home.
- Item category allowed only when kind is `ITEM`.
- No self-parent check constraint.
- Cycle prevention and subtree room updates on move are handled by RPC **`move_inventory_node`** (security definer), not by ad-hoc client updates alone.

Client behavior today:

- Browse children by `(home_id, room_id, parent_node_id)`.
- Create/update nodes with quantity, price, currency, dates, brand, etc.
- Repository exposes `moveNode` and `archiveNode`; move UI supports nested container destinations and long-press drag-drop onto containers in room browse.
- Breadcrumb helper exists in the repository; **breadcrumb UI is not built yet**.

Rooms remain a separate table (`rooms`) as the top spatial partition under a Home.

---

## Rationale

- **Simplicity:** One CRUD surface for furniture, storage, and items.
- **Scalability of model:** Unlimited nesting without schema migrations per depth.
- **Security:** Direct `home_id` on every row keeps RLS helpers uniform (ADR-0003).
- **Correctness:** Trusted move RPC centralizes cycle checks and descendant room propagation.

---

## Alternatives Considered

1. **Separate tables** (`furniture`, `containers`, `items`)  
   Rejected: joins and polymorphic parents become painful; item-as-container is awkward.

2. **Fixed-depth hierarchy** (Room → Furniture → Item only)  
   Rejected: cannot model nested boxes/bags.

3. **Materialized paths / nested sets**  
   Rejected for MVP: more write complexity; adjacency list + recursive CTE is enough for current scale.

4. **Client-only move with multiple UPDATEs**  
   Rejected as sole mechanism: race/cycle risk; RPC is authoritative.

---

## Consequences

### Advantages

- UI can reuse one create/edit form with kind switches.
- Search can scan one table (plus barcodes).
- Moving a container preserves descendant parent links; room_ids update as a subtree.

### Disadvantages

- Recursive queries required for path/cycle operations.
- Denormalized `room_id` can drift if someone bypasses RPC (mitigated by trigger on parent changes for inserts/updates, move RPC for moves).
- Soft archive fields exist; restore UX incomplete.

---

## Security Impact

- RLS: select for members; insert/update/delete for editors (`can_edit_inventory`).
- Insert requires `created_by_user_id = auth.uid()`.
- Move RPC re-checks `can_edit_inventory` and same-home destination.

---

## Database Impact

**Table:** `inventory_nodes`  
**Indexes:** `home_id`, `room_id`, `parent_node_id`, `(home_id, name)`  
**Trigger:** `inventory_nodes_validate`  
**RPC:** `move_inventory_node`  
**Related:** `rooms`

Item detail columns present today include quantity fields, purchase price/currency/dates, brand, optional **weight / weight_unit**, optional owner_user_id (column exists; assignment UI not built).

---

## API Impact

- PostgREST CRUD on `inventory_nodes` / `rooms`.
- RPC for moves.

---

## UI Impact

- Room / container screens list children.
- Create/edit node screen; detail screen for photos/barcodes/fields.
- Containers open nested browse; info action opens details.
- Search by name (and barcode — ADR-0006).

---

## Future Considerations

- Transactional quantity changes (USE/RESTOCK) will likely reference `inventory_nodes` without splitting the table — document in a future ADR when implemented.
- UI for move + breadcrumbs should call existing repository/RPC rather than inventing a second model.

---

## Architecture Notes

- Drift: `move_inventory_node` exists but no Flutter screen calls it yet.
- No DB trigger preventing cycles on direct `parent_node_id` UPDATE outside the RPC — editors could theoretically create a cycle with a raw update if they bypass the RPC. Consider a validation trigger if that becomes a threat.
- Name search is `ilike '%query%'`; may need trigram/`pg_trgm` if Homes get large.
- Category-specific attribute tables from planning are not implemented.

---

## References

- [`supabase/migrations/20260712000100_foundation.sql`](../../supabase/migrations/20260712000100_foundation.sql)
- [`mobile/lib/features/inventory/data/inventory_repository.dart`](../../mobile/lib/features/inventory/data/inventory_repository.dart)
- [`mobile/lib/shared/models/inventory_node.dart`](../../mobile/lib/shared/models/inventory_node.dart)
- [`mobile/lib/features/rooms/presentation/room_detail_screen.dart`](../../mobile/lib/features/rooms/presentation/room_detail_screen.dart)
- PR: [#12](https://github.com/Ezral/Homeventory/pull/12) (edit/detail UX)
- Related: [ADR-0003](0003-home-membership-rls.md), [ADR-0006](0006-private-images-and-barcodes.md)
