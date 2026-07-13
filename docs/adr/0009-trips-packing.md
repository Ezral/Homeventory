# ADR-0009

Trips packing and unpacking

## Status

Accepted

## Date

2026-07-12

---

## Context

Users pack belongings into mobile containers for trips and must return them to original locations. Packing must not bypass containment/move rules.

---

## Decision

Phase 6-super introduced trips tables. Later refinement (packing plan):

| Table | Role |
| --- | --- |
| `trips` | Trip metadata + status + luggage allowance + soft-delete |
| `trip_containers` | Mobile containers assigned to a trip |
| `trip_items` | Packing plan rows: `PLANNED` / `PACKED` / `UNPACKED` |

RPCs:

- `add_items_to_packing_plan` — batch add furniture descendants as `PLANNED`; revives `UNPACKED` rows on the same trip and inserts onto any other trip
- `pack_item_into_container` — mark `PACKED` **without relocating** inventory (also re-packs `UNPACKED` / `PLANNED`)
- `unpack_item` — return to `PLANNED` (still on checklist)
- `remove_from_packing_plan` — drop a non-packed plan row
- `list_node_descendants` / `list_room_packable_nodes` / `list_home_packed_nodes` — furniture or room multi-select + room greying

Flutter: packing plan multi-select from **furniture** or **room** (`ITEM` nodes only); checkboxes; packed items stay visible (greyed) in original furniture; hierarchical move destination browser; `UNPACKED` rows remain visible so they can be packed again.

---

## Rationale

- Correctness: reuse trusted move RPC + origin snapshot
- Security: editor-only; home-scoped
- Simplicity: templates deferred

---

## Alternatives Considered

1. Pack as only a checklist without moving nodes — rejected (location would lie)
2. Client multi-step update without RPC — rejected (race/partial failure)

---

## Consequences

### Advantages

- Unpack restores original containment
- Trip progress visible via trip_items status

### Disadvantages

- No packing templates yet
- Nested pack edge cases rely on move validation

---

## Security Impact

RLS via `can_view_home` / `can_edit_inventory`. RPCs enforce trip home matches nodes.

---

## Database Impact

Migration: `20260712000500_phase6_super.sql`

---

## API Impact

PostgREST on trips tables; RPCs pack/unpack.

---

## UI Impact

Home → Trips; trip detail for containers and packed items.

---

## Architecture Notes

- Luggage allowance (`luggage_allowance_kg`) + packed weight estimate (containers + PACKED items, normalized to kg)
- Soft-delete via `archived_at` (hidden in UI, row retained for audit)
- Trip metadata/status editable regardless of COMPLETED
- Container/item thumbnails on trip detail via `entityThumbnailsProvider`
- Packing is a checklist overlay (`PLANNED` / `PACKED` / `UNPACKED`): inventory stays in place; packed items are greyed in room browse
- Furniture- or room-scoped multi-select populates the packing plan; only `ITEM` nodes are listed (furniture/storage hidden)
- Unpacked items can be packed again on the same trip (checkbox / re-add) or any other trip (new `trip_items` row)

---

## References

- [`supabase/migrations/20260712000500_phase6_super.sql`](../../supabase/migrations/20260712000500_phase6_super.sql)
- [`supabase/migrations/20260713000600_trips_allowance_archive.sql`](../../supabase/migrations/20260713000600_trips_allowance_archive.sql)
- [`supabase/migrations/20260713000700_packing_plan_no_relocate.sql`](../../supabase/migrations/20260713000700_packing_plan_no_relocate.sql)
- [`supabase/migrations/20260713000800_repack_unpacked_any_trip.sql`](../../supabase/migrations/20260713000800_repack_unpacked_any_trip.sql)
- [`supabase/migrations/20260713000900_list_room_packable_nodes.sql`](../../supabase/migrations/20260713000900_list_room_packable_nodes.sql)
- [`mobile/lib/features/trips/`](../../mobile/lib/features/trips/)
- Related: [ADR-0005](0005-recursive-inventory-nodes.md), [ADR-0008](0008-inventory-transactions.md)
