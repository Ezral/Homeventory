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

Phase 6-super introduces:

| Table | Role |
| --- | --- |
| `trips` | Trip metadata + status |
| `trip_containers` | Mobile containers assigned to a trip |
| `trip_items` | Packed node + original room/parent snapshot + PACKED/UNPACKED |

RPCs:

- `pack_item_into_container(trip, node, bag)` — records origin, moves into bag via `move_inventory_node`, marks PACKED, writes MOVE transaction
- `unpack_item(trip_item)` — moves back to original room/parent, marks UNPACKED, writes MOVE transaction

Flutter: trips list/detail under a home; assign containers; pack/unpack actions.

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

---

## References

- [`supabase/migrations/20260712000500_phase6_super.sql`](../../supabase/migrations/20260712000500_phase6_super.sql)
- [`supabase/migrations/20260713000600_trips_allowance_archive.sql`](../../supabase/migrations/20260713000600_trips_allowance_archive.sql)
- [`mobile/lib/features/trips/`](../../mobile/lib/features/trips/)
- Related: [ADR-0005](0005-recursive-inventory-nodes.md), [ADR-0008](0008-inventory-transactions.md)
