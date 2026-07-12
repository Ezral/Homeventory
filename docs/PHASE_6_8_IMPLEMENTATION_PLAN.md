# Phase 6–8 Implementation Plan

Prep plan for the next product slice after the current catalog/map UX.
Derived from [`Homeventory_Full_Planning.md`](Homeventory_Full_Planning.md) §16–18, §25–26, §42 and [`IMPLEMENTATION.md`](IMPLEMENTATION.md).

**Do not start Phase 7 or 8 until Phase 6 transaction RPCs and history are reliable.**

Related ADRs to add when each phase lands (not yet written — features absent):

- Product / container stock model
- Inventory transactions
- Consumption predictions
- Packing architecture

---

## Current baseline (done)

- Homes, membership, RLS, invites
- Rooms + recursive `inventory_nodes`
- Item fields: quantity, min qty, price/currency, dates, brand
- Images (node + room) and barcodes (attach + search)
- Search by name/barcode
- Move RPC exists; **move UI still missing** (complete before or with Phase 6)

---

## Phase 6 — Inventory transactions + product containers

### Goal

Quantity changes become auditable events. Refills between containers do not look like consumption.

### Schema (new migration)

| Table | Purpose |
| --- | --- |
| `products` | Optional catalog identity shared across physical nodes (name, brand, barcode group) |
| `product_containers` | Links a product to one or more `inventory_nodes` that hold stock of that product |
| `inventory_transactions` | Append-only stock events |

Suggested transaction types (enum):

`INITIAL_STOCK`, `USE`, `RESTOCK`, `ADJUSTMENT`, `DISPOSE`, `TRANSFER_REFILL`

Core columns for `inventory_transactions`:

- `home_id`, `inventory_node_id`
- `transaction_type`
- `quantity_delta` (signed) and/or `quantity_before` / `quantity_after`
- `unit`
- `related_node_id` (for TRANSFER_REFILL source/destination)
- `reason` / notes
- `created_by_user_id`, `created_at`

### Trusted RPCs (security definer)

Implement atomic functions; **do not** let the client UPDATE `quantity` directly for stock changes once this ships.

| RPC | Behavior |
| --- | --- |
| `apply_inventory_transaction` | Validates membership + edit role, applies delta, inserts row, rejects silent negative stock |
| `transfer_refill` | Moves quantity from reserve node → active node; total across product containers unchanged; marked non-consumption |

Optional: stop allowing raw quantity edits on the create/edit form once transactions exist (or keep edit only as ADJUSTMENT with confirmation).

### Flutter work

1. Transaction repository + providers
2. Item detail actions: Use / Restock / Adjust / Dispose / Refill
3. Transaction history list on item detail
4. Wire product linking UI (minimal: “same product as…” or barcode-grouped)

### Acceptance

- USE reduces quantity and creates a history row
- RESTOCK increases quantity with history
- TRANSFER_REFILL does not change sum of linked product stock
- Viewer cannot create transactions
- Cross-Home IDs rejected by RLS/RPC

### Risks

- Double-submit on flaky networks → idempotency key or client request id
- Partial updates if quantity updated without transaction → forbid or trigger-enforce

---

## Phase 7 — Consumption predictions

### Goal

Explainable forecasts for “active container empty” and “all stock gone,” excluding refill transfers.

### Depends on

Phase 6 USE events with timestamps. Without enough USE history, show **low confidence / insufficient data** — never fake precision.

### Schema

`consumption_predictions` (or compute on read first, persist later):

- `home_id`, `product_id` or `inventory_node_id`
- `active_container_days_remaining`
- `total_stock_days_remaining`
- `confidence` (`LOW` / `MEDIUM` / `HIGH`)
- `explanation` text
- `computed_at`

### Algorithm (MVP)

1. Take recent USE deltas for the product (exclude TRANSFER_REFILL, ADJUSTMENT optional exclude)
2. Rate = average quantity used per day over a window (e.g. 14–30 days)
3. Active forecast = active container qty / rate
4. Total forecast = sum(linked containers) / rate
5. Confidence from sample size + variance

### Flutter work

- Prediction section on item / product detail
- Optional home dashboard cards (can wait for Phase 10 UI; data layer first)

### Acceptance

- Refill events do not accelerate depletion forecast
- Empty explanation string never shown as a number without confidence label
- No prediction when rate cannot be computed

### Risks

- Users misread LOW confidence as certainty → UI copy must be blunt
- Seasonality out of scope (post-MVP)

---

## Phase 8 — Packing and unpacking

### Goal

Assign mobile containers to a Trip, pack items with original location capture, unpack selectively back to origin.

### Depends on

- `is_mobile_container` already on nodes
- Stable containment + move RPC (use move or a pack-specific location snapshot)

### Schema

| Table | Purpose |
| --- | --- |
| `trips` | Trip metadata (name, dates, home_id, status) |
| `trip_containers` | Mobile containers assigned to a trip |
| `trip_items` | Packed items + original room/parent snapshot + unpack status |
| `packing_templates` / `packing_template_items` | Reusable lists |

Pack action should store:

- `original_room_id`, `original_parent_node_id` (and optionally path label)
- Packed-into container id
- Status: PACKED / UNPACKED / MISSING_CONFIRMATION

### Trusted RPCs

- `pack_item_into_container` — snapshot origin, reparent/move into mobile container, write trip_items
- `unpack_item` — restore to original parent/room via move RPC semantics
- `complete_trip_check` — list items still PACKED

### Flutter work

1. Trips list + create trip
2. Assign suitcase/bag to trip
3. Pack via browse/search/scan
4. Unpack selective + “return all”
5. Templates: save from trip / apply to new trip (basic)

### Acceptance

- Packed item remembers origin and can return there
- Nested contents of a packed container remain consistent
- Trip completion surfaces unconfirmed items
- Viewer read-only

### Risks

- Packing state vs inventory location divergence if client updates parent without RPC
- Weight estimation can wait until after pack/unpack works

---

## Suggested build order (prep → ship)

1. **Move UI** (uses existing `move_inventory_node`) — unblocks packing and refill placement
2. **Phase 6 schema + RPCs + SQL tests**
3. **Phase 6 Flutter actions + history**
4. **Phase 7 read-model / job + UI badges**
5. **Phase 8 trips schema + pack/unpack RPCs + UI**
6. ADR for each landed decision in the same PR as the migration

### Explicitly defer (not Phase 6–8)

FCM / notification center · full dashboard · audit_logs subsystem · offline sync · multi-batch expiration · AI / OCR

---

## Test plan (minimum)

| Layer | Cases |
| --- | --- |
| SQL | Cross-home transaction denied; negative stock rejected; refill preserves sum |
| SQL | Pack → unpack restores parent; cycle still rejected |
| Flutter | Use/restock happy path; viewer cannot mutate |
| Flutter | Pack/unpack navigation + empty states |

---

## Definition of ready for implementation PRs

A Phase 6 PR is ready when it includes:

- Migration + RLS + grants
- RPC(s) + at least one SQL authorization test
- Flutter repository + item actions + history
- ADR update/create
- APK version bump if mobile paths change
