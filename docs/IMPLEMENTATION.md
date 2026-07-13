# Homeventory Implementation Backlog

Derived from [`Homeventory_Full_Planning.md`](Homeventory_Full_Planning.md) §41–46.

Architecture decisions that are already implemented are recorded in [`docs/adr/`](adr/). Update or add an ADR in the same PR when architecture changes.

| Plan | Role |
| --- | --- |
| [`PHASE_6_8_IMPLEMENTATION_PLAN.md`](PHASE_6_8_IMPLEMENTATION_PLAN.md) | Phase 6-super (shipped) + full 6/7 depth + Phase 8 predictions |
| [`UAT_PHASE6_SUPER_FOLLOWUP.md`](UAT_PHASE6_SUPER_FOLLOWUP.md) | **Next ship sequence A–J** from 6-super UAT (home profile, nav, room permissions, FX, …) |

Do not build predictions or push notifications before Home authorization is trustworthy. Prefer **A–C** before deep Phase 8 unless product reorders. Room privacy (**G**) before claiming multi-member dashboard valuation (**I**).

## Recommended build order (updated)

1. Google authentication — done  
2. Profiles — done  
3. Homes — done (edit + cover photo partial)  
4. Membership and RLS — done (home-wide roles; **room-level roles = D+**)  
5. Rooms — done  
6. Recursive inventory nodes — done  
7. Search — done (privacy filtering = G)  
8. Images — done  
9. Barcode scanning — done  
10. Quantity transactions + Trips MVP — **Phase 6-super shipped**  
11. **A–C** Home profile polish, shell navigation, dashboard metrics  
12. **D–G** Read-only home default, room requests, room invites/temp access, visibility + inheritance  
13. **H** Multi-dispenser product slots (+ remaining Phase 6 product graph as needed)  
14. **I** Display currency, FX cache, estimated inventory value  
15. **J** In-app notifications, permission audit, loading polish, regression UAT  
16. Phase 8 consumption predictions (when USE history is sufficient)  
17. Hardening and release  

---

## Phase 1 — Foundation

**Goal:** Signed-in users with profiles; project, environments, and RLS patterns established.

- [x] Create Flutter app under `mobile/`
- [x] Connect Supabase project (dev + prod) — GitHub integration linked to `eynsgdzsunlhzrxznriz`; merge migrations to `main` to deploy
- [ ] Configure Firebase (FCM later; project bootstrap now)
- [x] Google SSO via Supabase Auth (client wired; needs live OAuth credentials)
- [x] Profile creation on first sign-in (`profiles` row matching `auth.users.id`)
- [x] Secure session storage; clear private local state on logout
- [ ] Logging and error handling
- [x] RLS helper functions and deny-by-default policy pattern (SQL)

### Acceptance

- User can sign in with Google
- First sign-in creates a profile; existing users are not duplicated
- Logout clears private local state
- Service-role credentials are absent from the APK

---

## Phase 2 — Home and Membership

**Goal:** Multi-Home collaboration with roles and invite codes.

- [x] Schema: `homes`, `home_members`, `invitations`
- [x] Create / edit / archive Home (create + edit UI + photo; archive API)
- [x] Home selector UI
- [x] Invite via token + short code (hashed, single-use, expiring; QR later)
- [x] Accept invitation → ACTIVE membership (token **or** short code)
- [x] Role assignment: OWNER, ADMIN, EDITOR, VIEWER
- [x] Remove member; immediate access loss (`remove_home_member` + UI)
- [x] Membership RLS policies
- [x] Membership RLS integration tests (SQL smoke + `scripts/validate-migrations.sh`)

### Acceptance

- Multiple Homes per user
- Join via invitation
- Viewer cannot modify data
- Removed member loses access immediately
- UUID guessing cannot cross Homes

### UAT follow-up (Phase A / D)

- [ ] `residing_since`, `remarks`, `updated_by`; residence duration UI
- [ ] Home header layout: wrap name, members under name, declutter chips, image remove/fallback
- [ ] New members **read-only by default** (breaking vs current EDITOR default invites)
- [ ] Room-level roles supersede home-wide edit for day-to-day inventory (see D–G)

---

## Phase 3 — Rooms and Inventory Hierarchy

**Goal:** Physical containment model with cycle-safe moves.

- [x] Schema: `rooms`, `inventory_nodes`
- [x] Room CRUD and ordering (create + list; reorder UI later)
- [x] Inventory node CRUD (furniture, storage locations, items — create/list)
- [x] Nested containers; items that are also containers
- [ ] Breadcrumb / location path (repository helper present; UI later)
- [x] Move validation + cycle prevention (trusted SQL function + client RPC)
- [ ] Archive and restore
- [x] Hierarchy RLS + parent/Home consistency helpers

### Acceptance

- Room can contain furniture and items
- Container can contain another container
- Suitcase can be both item and container
- No fixed nesting depth
- Cyclic containment rejected
- Moving a container preserves descendants

### UAT follow-up (Phase E–G)

- [ ] Room creation requests + owner approval
- [ ] Room ownership / co-ownership
- [ ] Room invitations + temporary access
- [ ] Room visibility (all / restricted / private) + object permission inheritance

---

## Phase 4 — Item Details

- [x] Categories: EDIBLE, CONSUMABLE, CLOTHING, BAG_LUGGAGE, ELECTRONICS, MISC
- [x] Quantity, units, min quantity
- [x] Price, currency, purchase date
- [x] Optional weight + weight unit (all node kinds)
- [ ] Owner assignment
- [x] Expiration date
- [ ] Category-specific attributes (`item_category_attributes`)
- [ ] `price_basis` (per unit vs total), `include_in_home_value` (Phase I)

---

## Phase 5 — Images and Barcode

- [x] Schema: `images`, `item_barcodes`
- [x] Camera primary; gallery secondary
- [ ] Crop / resize; EXIF GPS strip (basic resize via image_picker quality/max dims)
- [x] Private Storage bucket + signed URLs
- [x] Barcode scan → lookup / attach to item
- [ ] Internal QR labels
- [ ] Page-ready loading: wait for initial viewport images (Phase J)

---

## Phase 6-super — Shipped (stock + Trips MVP)

See checklist: [`PHASE_6_8_IMPLEMENTATION_PLAN.md`](PHASE_6_8_IMPLEMENTATION_PLAN.md).

### Stock (Must)

- [x] Move UI (`move_inventory_node`)
- [x] `inventory_transactions` + `apply_inventory_transaction`
- [x] USE / RESTOCK / ADJUSTMENT / **DISPOSE** + history UI
- [x] Dispose sets `is_disposed = true` and hides item from normal lists (no hard delete)
- [x] Unit `CC` + dispenser capacity MVP
- [x] Stock actions leave an append-only transaction trail (not full app-wide `audit_logs` yet)

### Trips (Must)

- [x] `trips`, `trip_containers`, `trip_items`
- [x] Pack / unpack RPCs with original location snapshot
- [x] Create trip → assign mobile container → pack → unpack

### Should (follow-up)

- [x] TRANSFER_REFILL RPC (server); thin refill UI still optional
- [ ] Thin product/reserve link tables
- [ ] Pack via barcode; still-packed list polish
- [ ] Move appears in item history when using Move UI; optional disposed-items view

### Defer

- [ ] Packing templates; full product catalog; Phase 8 predictions; global permission `audit_logs` (J)

---

## Next ship — UAT follow-up phases A–J

Canonical detail + acceptance + UAT checklist: [`UAT_PHASE6_SUPER_FOLLOWUP.md`](UAT_PHASE6_SUPER_FOLLOWUP.md).

| Phase | Goal | Status |
| --- | --- | --- |
| **A** | Home profile polish (residing date, remarks, layout, image remove) | **In progress / this ship** |
| **B** | Bottom nav, user menu, contextual FAB | **In progress / this ship** |
| **C** | Dashboard cards (rooms, base furniture, members, duration, value stub) | **In progress / this ship** |
| **D** | Read-only home default + room permission foundation | Not started |
| **E** | Room creation requests + room owner / co-owner | Not started |
| **F** | Room invitations + temporary access | Not started |
| **G** | Room visibility + object inheritance + query privacy | Not started |
| **H** | Single/multi dispenser product slots | Not started |
| **I** | Display currency, FX cache, estimated inventory value | Not started |
| **J** | Notifications, permission audit, loading polish, regression UAT | Not started |

---

## Phase 6 — Inventory Transactions (full depth)

See [`PHASE_6_8_IMPLEMENTATION_PLAN.md`](PHASE_6_8_IMPLEMENTATION_PLAN.md). Core MVP under **Phase 6-super**; remaining depth + **H**.

- [x] Schema core: `inventory_transactions` + apply RPC (MVP)
- [ ] Schema: `products`, `product_containers`
- [x] Object dispensers MVP: `is_dispenser`, `capacity`, unit **`CC`**
- [ ] Multi dispenser slots + `is_dispensable` (Phase H)
- [x] USE, RESTOCK, ADJUSTMENT, DISPOSE (+ TRANSFER_REFILL RPC)
- [ ] TRANSFER_REFILL UI; multi-reserve defaults
- [x] Transaction history UI

---

## Phase 7 — Packing and Unpacking (Trips, full depth)

See [`PHASE_6_8_IMPLEMENTATION_PLAN.md`](PHASE_6_8_IMPLEMENTATION_PLAN.md). Core MVP under **Phase 6-super**.

- [x] Schema core: `trips`, `trip_containers`, `trip_items`
- [ ] Packing templates
- [x] Assign mobile containers to Trips
- [x] Pack with original location capture
- [x] Selective unpack / return to original
- [ ] Completion check for unconfirmed items

---

## Phase 8 — Predictions

See [`PHASE_6_8_IMPLEMENTATION_PLAN.md`](PHASE_6_8_IMPLEMENTATION_PLAN.md). Needs USE history; schedule relative to A–J per product priority.

- [ ] Schema: `consumption_predictions`
- [ ] Active dispenser / container refill forecast (**CC/day** for volume products)
- [ ] Total-stock depletion forecast
- [ ] Confidence labels and explanations
- [ ] Exclude refill transfers from consumption

---

## Former Phase 9–11 (superseded by A–J)

Old backlog slots for notifications / dashboard / release quality are **replaced** by follow-up phases:

- Notifications → **J** (in-app first; FCM still later)
- Dashboard → **C** + valuation **I** (privacy **G**)
- Search filters / privacy → **G**
- Loading / regression → **J**
- Play Store / hardening → after J regression UAT

---

## MVP include list (planning §41.1)

Google SSO · profiles · multi-Home · invites · roles · rooms · inventory nodes · nested containers · item-as-container · categories · quantity/units · price/currency/purchase date · expiration · images · barcode · use/restock/refill · search · move · basic predictions · packing · templates · in-app + Android push · audit history · private images · RLS tests · archive-over-delete

**UAT amendment:** home profile dashboard, shell navigation, read-only home default, room-level permissions/requests/invites/visibility, multi-dispenser, display-currency valuation — tracked in A–J before claiming full multi-member MVP.

## Explicitly post-MVP

Full offline sync · seasonality · AI recognition · receipt OCR · auto barcode product lookup · multi-batch expiration · warranty · airline baggage rules · lending · messaging · NFC · smart home · insurance reports · shopping integrations · depreciation · historical FX valuation · iOS · web dashboard · email/push (beyond in-app) · exportable valuation reports · dashboard charts
