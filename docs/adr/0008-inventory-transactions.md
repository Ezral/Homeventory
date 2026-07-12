# ADR-0008

Inventory transactions and dispose

## Status

Accepted

## Date

2026-07-12

---

## Context

Quantity changes must be auditable. Users need Use / Restock / Adjust / Dispose. Disposed items should leave normal inventory views without hard delete. Dispensers need capacity-aware remaining quantity (often in CC).

---

## Decision

Stock mutations go through security-definer RPC `apply_inventory_transaction`, which updates `inventory_nodes.quantity` (when applicable) and inserts an append-only `inventory_transactions` row.

Transaction types in schema: `INITIAL_STOCK`, `USE`, `RESTOCK`, `ADJUSTMENT`, `DISPOSE`, `TRANSFER_REFILL`, `MOVE`.

Node fields added:

- `is_disposed` / `disposed_at` — DISPOSE sets these; list/search filter `is_disposed = false`
- `is_dispenser` / `capacity` — dispenser MVP; RESTOCK/TRANSFER_REFILL reject over-capacity

Clients must not UPDATE quantity for stock actions; UI calls the RPC. Ledger rows have no update/delete policies for clients.

TRANSFER_REFILL debits a related source node and credits the target in one RPC (two ledger rows).

---

## Rationale

- Security: editors only; cross-home blocked via helpers
- Audit: every stock action has a trail
- Soft dispose preserves history

---

## Alternatives Considered

1. Client-side quantity UPDATE + optional log — rejected (races, missing audit)
2. Hard delete on dispose — rejected (planning: archive/dispose over delete)
3. Full `products` graph required before any USE — deferred; node-level quantity is enough for MVP

---

## Consequences

### Advantages

- Auditable USE/RESTOCK/ADJUST/DISPOSE
- Disposed items hidden from default lists
- Capacity protection for dispensers

### Disadvantages

- Dual quantity sources until UI stops free-form qty edits
- Full product/reserve catalog still thin

---

## Security Impact

RLS on `inventory_transactions`: members select; editors insert only as self; no client update/delete. RPC re-checks `can_edit_inventory`.

---

## Database Impact

Migration: `20260712000500_phase6_super.sql`

---

## API Impact

RPC `apply_inventory_transaction`; PostgREST select on `inventory_transactions`.

---

## UI Impact

Node detail: Use / Restock / Adjust / Dispose + history. Create/edit: dispenser + capacity. Lists hide disposed.

---

## Architecture Notes

- MOVE type exists for pack/unpack trail; move UI may not always write MOVE yet when using `move_inventory_node` alone.
- Global `audit_logs` still deferred.

---

## References

- [`supabase/migrations/20260712000500_phase6_super.sql`](../../supabase/migrations/20260712000500_phase6_super.sql)
- [`mobile/lib/features/inventory/data/inventory_repository.dart`](../../mobile/lib/features/inventory/data/inventory_repository.dart)
- Related: [ADR-0005](0005-recursive-inventory-nodes.md), [ADR-0009](0009-trips-packing.md)
