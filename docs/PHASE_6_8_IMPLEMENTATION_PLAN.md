# Phase 6–8 Implementation Plan

Prep plan for the next product slice after the current catalog/map UX.
Derived from [`Homeventory_Full_Planning.md`](Homeventory_Full_Planning.md) §16–18, §25–26, §42 and [`IMPLEMENTATION.md`](IMPLEMENTATION.md).

## Phase numbering

| Phase | Scope |
| --- | --- |
| **6-super (next ship)** | Combined **MVP** of stock transactions + Trips/packing |
| **6 (full)** | Richer product graph, refill UX polish, dispenser linking beyond MVP |
| **7 (full)** | Packing templates, trip completion polish, weight estimates |
| **8** | Consumption predictions (CC/day) — **after UAT of 6-super** |

### Why ship 6 + 7 together as 6-super?

Yes — **ideal as one MVP program**, not as two complete phases dumped into one APK.

| Shared foundation | Why combine |
| --- | --- |
| Move UI + `move_inventory_node` | Needed for refill placement **and** pack/unpack |
| Trusted RPCs + RLS patterns | Same migration style, same security review |
| Item detail / scan / search | Shared surfaces for USE and “pack this” |
| One UAT pass | Household flow: use soap → pack suitcase → return |

**Not ideal:** implementing *every* Phase 6 and Phase 7 checkbox before shipping. That is two full phases. **6-super** means one coherent MVP with explicit deferrals.

**Gate for Phase 8:** start predictions only after **UAT sign-off on Phase 6-super**.

Related ADRs to add when 6-super lands (not yet written):

- Inventory transactions (+ thin product/dispenser model)
- Packing / trips architecture

---

## Current baseline (done)

- Homes, membership, RLS, invites
- Rooms + recursive `inventory_nodes`
- Item fields: quantity, min qty, price/currency, dates, brand, optional weight
- Images (node + room) and barcodes (attach + search)
- Search by name/barcode
- `is_mobile_container` flag on nodes
- Move RPC exists; **move UI still missing**

---

# Phase 6-super — MVP checklist (next APK target)

Ship when **all Must** items below are done. Should / Could can slip to a follow-up APK without blocking UAT of the core loop.

## Must have (blocks ship)

### Foundation

- [ ] **Move UI** — pick destination room + optional parent container; calls `move_inventory_node`
- [ ] Migration(s) with RLS + grants + SQL auth smoke tests
- [ ] ADRs for transactions and trips (same PR as schema)
- [ ] APK version bump

### Stock (Phase 6 slice)

- [ ] Table `inventory_transactions` + enum types at least: `USE`, `RESTOCK`, `ADJUSTMENT`, `DISPOSE` (and `INITIAL_STOCK` if easy)
- [ ] RPC `apply_inventory_transaction` — atomic qty change + history; reject negative stock; editor-only
- [ ] Item detail actions: **Use / Restock / Adjust / Dispose**
- [ ] Transaction **history** list on item detail (and still readable after dispose)
- [ ] Quantity unit includes **`CC`** (and existing free-text units)
- [ ] **Dispenser MVP:** mark node as dispenser + optional `capacity`; remaining = node `quantity` in CC (full `products` / multi-reserve graph can be thin)
- [ ] **Dispose MVP:** `DISPOSE` sets `is_disposed = true` (and optional `disposed_at`); node **disappears from normal room/search lists**; not hard-deleted

### Dispose behavior (Must)

When the user no longer has / no longer tracks an object:

1. Confirm Dispose on item detail (reason optional).
2. Write `inventory_transactions` row with type `DISPOSE` (who, when, qty before, notes).
3. Set `inventory_nodes.is_disposed = true` (prefer also `disposed_at timestamptz` for sorting/audit).
4. Default queries filter `is_disposed = false` (same idea as today’s `archived_at is null` filters).
5. Do **not** hard-delete the row or its transaction history.

Optional later (not Must): “Show disposed” / restore from dispose.

### Audit trail — what 6-super guarantees vs later

**Not every app action has a global audit log today**, and full `audit_logs` remains **deferred**.

| Action family | Trail in Phase 6-super |
| --- | --- |
| USE / RESTOCK / ADJUSTMENT / DISPOSE / (TRANSFER_REFILL if shipped) | **Yes** — `inventory_transactions` (append-only stock ledger) |
| Pack / unpack | **Partial** — `trip_items` + original location snapshot + status; not a general audit table |
| Move between rooms/containers | **RPC only** unless we also write a transaction or move event row (Should: log move as history) |
| Create/edit name, photos, barcodes, invites, etc. | **No** dedicated audit trail in 6-super |

So: **every stock action has an audit trail** via `inventory_transactions`.  
**Not every UI action** (edit title, upload photo, invite member) gets an audit row until a later `audit_logs` phase.

**Should have for moves:** write a lightweight history event (either a transaction type `MOVE` or a small `inventory_events` / reuse transactions with zero qty delta) so location changes are also trailable.

### Trips (Phase 7 slice)

- [ ] Tables: `trips`, `trip_containers`, `trip_items` (status PACKED / UNPACKED)
- [ ] RPC `pack_item_into_container` — snapshot `original_room_id` + `original_parent_node_id`, move into mobile container
- [ ] RPC `unpack_item` — restore via move semantics
- [ ] Flutter: create trip → assign mobile container → pack (browse/search) → unpack one / unpack all
- [ ] Viewer cannot mutate stock or pack

### UAT scenarios (must pass)

1. Use 15 CC from a soap dispenser; history shows USE; qty drops  
2. Restock / adjust works; viewer cannot  
3. **Dispose** an item; it vanishes from room list/search; history still shows DISPOSE; row not hard-deleted  
4. Move an item between rooms/containers  
5. Create trip, assign suitcase, pack item, unpack → item back at original location  
6. Cross-home IDs cannot mutate via RPC  

---

## Should have (same APK if time; else immediate follow-up)

- [ ] `TRANSFER_REFILL` RPC + simple “refill dispenser from another node” UI (same unit; respect capacity)
- [ ] Thin `products` + `product_containers` (ACTIVE/RESERVE, `is_dispenser`) linking dispenser + one reserve
- [ ] Pack via **barcode scan**
- [ ] Trip “still packed” list (completion check without templates)
- [ ] Stop raw qty edit on form (force ADJUSTMENT) once transactions exist
- [ ] Move actions appear in item history (zero-qty `MOVE` or equivalent)
- [ ] Optional “Disposed items” view / undo dispose (clears `is_disposed`, writes restore note)

## Could have / defer (not 6-super)

- [ ] Packing **templates**
- [ ] Full product catalog / barcode product groups
- [ ] Multi-reserve shopping UX polish
- [ ] Trip weight estimates / airline limits
- [ ] Predictions / CC/day (Phase 8)
- [ ] Notifications, dashboard, **global `audit_logs`**, offline

---

## Full Phase 6 (after 6-super) — remaining depth

### Goal

Richer product/container stock model; refill transfers that preserve total product stock.

### Schema additions (if not already in 6-super Should)

| Table | Purpose |
| --- | --- |
| `products` | Catalog identity (name, brand, default_unit, barcode group) |
| `product_containers` | ACTIVE/RESERVE, `is_dispenser`, capacity, link to `inventory_nodes` |

### Remaining work

- Multi-reserve TRANSFER_REFILL as default path
- Product linking UX (“same product as…”)
- Enforce one `default_unit` per product

---

## Full Phase 7 (after 6-super) — remaining depth

### Goal

Templates and trip completion polish.

### Remaining work

- `packing_templates` / `packing_template_items`
- Save template from trip / apply to new trip
- Missing-item / confirmation UX polish
- Optional packed weight rollup using item weights

---

## Phase 8 — Consumption predictions

### Goal

Explainable **CC/day** (or unit/day) forecasts for active dispenser and total stock.

### Gate

**Only after UAT of Phase 6-super.** Needs real USE history (including CC).

### MVP when started

- Rate from USE (exclude TRANSFER_REFILL)
- Active dispenser days remaining + total stock days remaining
- Confidence label + short explanation
- No fake precision when sample size is too small

---

## Suggested implementation order inside 6-super

1. Move UI  
2. Transactions schema + `apply_inventory_transaction` + SQL tests + item actions/history  
3. Dispenser fields (capacity + CC)  
4. Trips schema + pack/unpack RPCs + SQL tests  
5. Trips Flutter UI  
6. Should-haves if schedule allows  
7. ADRs + APK bump + UAT checklist  

PRs may still be split (foundation → stock → trips) but **one ship / one UAT** for 6-super.

---

## Definition of ready

A 6-super ship PR (or PR set) is ready when:

- All **Must have** checklist items are done  
- SQL + Flutter smoke for UAT scenarios above pass  
- ADR(s) created/updated  
- APK version bumped  

Phase 8 additionally requires documented **6-super UAT** completion.
