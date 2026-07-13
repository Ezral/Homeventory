# Phase 6–8 Implementation Plan

Prep plan for the catalog/map → stock → trips → predictions slice.
Derived from [`Homeventory_Full_Planning.md`](Homeventory_Full_Planning.md) §16–18, §25–26, §42 and [`IMPLEMENTATION.md`](IMPLEMENTATION.md).

**Status:** Phase **6-super MVP shipped**. Post–UAT product work (home profile polish, shell nav, room-level permissions, dashboard valuation, etc.) lives in [`UAT_PHASE6_SUPER_FOLLOWUP.md`](UAT_PHASE6_SUPER_FOLLOWUP.md) as phases **A–J**.

## Phase numbering

| Phase | Scope |
| --- | --- |
| **6-super (shipped)** | Combined **MVP** of stock transactions + Trips/packing |
| **6 (full)** | Richer product graph, refill UX polish, dispenser linking beyond MVP |
| **7 (full)** | Packing templates, trip completion polish, weight estimates |
| **8** | Consumption predictions (CC/day) — after meaningful USE history; coordinate with A–J |
| **A–J** | UAT follow-up (profile, nav, dashboard, room permissions, FX, …) — see follow-up plan |

### Why ship 6 + 7 together as 6-super?

Yes — **ideal as one MVP program**, not as two complete phases dumped into one APK.

| Shared foundation | Why combine |
| --- | --- |
| Move UI + `move_inventory_node` | Needed for refill placement **and** pack/unpack |
| Trusted RPCs + RLS patterns | Same migration style, same security review |
| Item detail / scan / search | Shared surfaces for USE and “pack this” |
| One UAT pass | Household flow: use soap → pack suitcase → return |

**Not ideal:** implementing *every* Phase 6 and Phase 7 checkbox before shipping. That is two full phases. **6-super** means one coherent MVP with explicit deferrals.

**Next after 6-super UAT:** prefer phases **A–C** (home profile, shell, dashboard shell) before full product-graph depth, unless product reorders. Room privacy (**G**) gates trustworthy multi-member dashboard totals (**I**).

Related ADRs (6-super):

- [`0008-inventory-transactions.md`](adr/0008-inventory-transactions.md)
- [`0009-trips-packing.md`](adr/0009-trips-packing.md)

---

## Current baseline (done)

- Homes, membership, RLS, invites
- Rooms + recursive `inventory_nodes`
- Item fields: quantity, min qty, price/currency, dates, brand, optional weight
- Images (node + room + **home cover**) and barcodes (attach + search)
- Search by name/barcode
- `is_mobile_container` flag on nodes
- Move UI + stock transactions + dispose + dispenser capacity MVP + Trips pack/unpack
- Home edit (owner): name, description, address, timezone, currency, cover photo

---

# Phase 6-super — MVP checklist (shipped)

Ship when **all Must** items below are done. Should / Could can slip to a follow-up APK without blocking UAT of the core loop.

## Must have (blocks ship)

### Foundation

- [x] **Move UI** — pick destination room + optional parent container; calls `move_inventory_node`
- [x] Migration(s) with RLS + grants + SQL auth smoke tests
- [x] ADRs for transactions and trips (same PR as schema)
- [x] APK version bump

### Stock (Phase 6 slice)

- [x] Table `inventory_transactions` + enum types at least: `USE`, `RESTOCK`, `ADJUSTMENT`, `DISPOSE` (and `INITIAL_STOCK` if easy)
- [x] RPC `apply_inventory_transaction` — atomic qty change + history; reject negative stock; editor-only
- [x] Item detail actions: **Use / Restock / Adjust / Dispose**
- [x] Transaction **history** list on item detail (and still readable after dispose)
- [x] Quantity unit includes **`CC`** (and existing free-text units)
- [x] **Dispenser MVP:** mark node as dispenser + optional `capacity`; remaining = node `quantity` in CC (full `products` / multi-reserve graph can be thin)
- [x] **Dispose MVP:** `DISPOSE` sets `is_disposed = true` (and optional `disposed_at`); node **disappears from normal room/search lists**; not hard-deleted

### Dispose behavior (Must)

When the user no longer has / no longer tracks an object:

1. Confirm Dispose on item detail (reason optional).
2. Write `inventory_transactions` row with type `DISPOSE` (who, when, qty before, notes).
3. Set `inventory_nodes.is_disposed = true` (prefer also `disposed_at timestamptz` for sorting/audit).
4. Default queries filter `is_disposed = false` (same idea as today’s `archived_at is null` filters).
5. Do **not** hard-delete the row or its transaction history.

Optional later (not Must): “Show disposed” / restore from dispose.

### Audit trail — what 6-super guarantees vs later

**Not every app action has a global audit log today**, and full `audit_logs` remains **deferred** (see follow-up phase **J** for permission audit).

| Action family | Trail in Phase 6-super |
| --- | --- |
| USE / RESTOCK / ADJUSTMENT / DISPOSE / (TRANSFER_REFILL if shipped) | **Yes** — `inventory_transactions` (append-only stock ledger) |
| Pack / unpack | **Partial** — `trip_items` + original location snapshot + status; not a general audit table |
| Move between rooms/containers | **RPC only** unless we also write a transaction or move event row (Should: log move as history) |
| Create/edit name, photos, barcodes, invites, etc. | **No** dedicated audit trail in 6-super |

So: **every stock action has an audit trail** via `inventory_transactions`.  
**Not every UI action** (edit title, upload photo, invite member) gets an audit row until a later `audit_logs` phase.

**Should have for moves:** write a lightweight history event (either a transaction type `MOVE` or a small `inventory_events` / reuse transactions with zero qty delta) so location changes are also trailable.

### Refill quantity semantics (ground truth for Phase 6 + Phase 8)

Yes — a refill always has an explicit **quantity**, not an implicit “fill to full.”

Example:

```text
Dispenser capacity:     300 CC
Remaining before:       150 CC   (half empty)
User refills:           150 CC
Remaining after:        300 CC
```

Rules to implement:

1. UI/RPC accepts `refill_quantity` (e.g. 150 CC).
2. Cap: `remaining_after = min(capacity, remaining_before + refill_quantity)` when capacity is set; reject or clamp overflow.
3. Ledger: write `TRANSFER_REFILL` (from reserve → dispenser) or `RESTOCK` (bought stock poured in) with that quantity on both sides as needed.
4. **TRANSFER_REFILL does not change total product stock** across linked containers; it only moves volume.
5. **TRANSFER_REFILL / RESTOCK are not consumption** — Phase 8 usage rate is computed from **USE** only.

Phase 8 prediction ground truth (later stage, locked now):

| Forecast | Formula |
| --- | --- |
| **When will this dispenser need refill again?** | `remaining_cc / cc_per_day` using **current remaining** after any refill |
| **When will all stock run out?** | `sum(active + reserve remaining) / cc_per_day` |
| Usage rate `cc_per_day` | Average of **USE** deltas over a window — **exclude** TRANSFER_REFILL and RESTOCK |

So after topping up 150 CC into a half-empty 300 CC dispenser, “days until empty” is recalculated from **300 CC**, not from the pre-refill 150 CC. Refill events extend the horizon; they do not inflate the usage rate.

### Trips (Phase 7 slice)

- [x] Tables: `trips`, `trip_containers`, `trip_items` (status PACKED / UNPACKED)
- [x] RPC `pack_item_into_container` — snapshot `original_room_id` + `original_parent_node_id`, move into mobile container
- [x] RPC `unpack_item` — restore via move semantics
- [x] Flutter: create trip → assign mobile container → pack (browse/search) → unpack one / unpack all
- [x] Viewer cannot mutate stock or pack

### UAT scenarios (must pass)

1. Use 15 CC from a soap dispenser; history shows USE; qty drops  
2. Restock / adjust works; viewer cannot  
3. **Dispose** an item; it vanishes from room list/search; history still shows DISPOSE; row not hard-deleted  
4. Move an item between rooms/containers  
5. Create trip, assign suitcase, pack item, unpack → item back at original location  
6. Cross-home IDs cannot mutate via RPC  

---

## Should have (follow-up APK; not blocking A–J)

- [ ] `TRANSFER_REFILL` simple “refill dispenser from another node” UI (RPC exists)
- [ ] Thin `products` + `product_containers` (ACTIVE/RESERVE, `is_dispenser`) linking dispenser + one reserve
- [ ] Pack via **barcode scan**
- [ ] Trip “still packed” list (completion check without templates)
- [ ] Stop raw qty edit on form (force ADJUSTMENT) once transactions exist
- [ ] Move actions appear in item history (zero-qty `MOVE` or equivalent)
- [ ] Optional “Disposed items” view / undo dispose (clears `is_disposed`, writes restore note)

## Could have / defer

- [ ] Packing **templates**
- [ ] Full product catalog / barcode product groups
- [ ] Multi-reserve shopping UX polish
- [ ] Trip weight estimates / airline limits
- [ ] Predictions / CC/day (Phase 8)
- [ ] See **A–J** for notifications, dashboard, permission audit, FX (no longer a vague “defer” bucket)

---

## Full Phase 6 (after 6-super) — remaining depth

### Goal

Richer product/container stock model; refill transfers that preserve total product stock.

Coordinate with follow-up **H** (multi-dispenser product slots).

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

Needs real USE history (including CC). Prefer after 6-super UAT and enough household usage; can run in parallel with mid A–J if product prioritizes forecasts over room privacy.

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

Post–UAT work is tracked in [`UAT_PHASE6_SUPER_FOLLOWUP.md`](UAT_PHASE6_SUPER_FOLLOWUP.md).
