# Homeventory Implementation Backlog

Derived from [`Homeventory_Full_Planning.md`](Homeventory_Full_Planning.md) §41–46.

Architecture decisions that are already implemented are recorded in [`docs/adr/`](adr/). Update or add an ADR in the same PR when architecture changes.

Do not build predictions, packing, or push notifications before Home authorization and the inventory hierarchy are reliable.

## Recommended build order

1. Google authentication
2. Profiles
3. Homes
4. Membership and RLS
5. Rooms
6. Recursive inventory nodes
7. Search
8. Images
9. Barcode scanning
10. Quantity transactions
11. Product containers and refill
12. Predictions
13. Packing and unpacking
14. Notifications
15. Hardening and release

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
- [x] Create / edit / archive Home (create + archive API; edit UI later)
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

---

## Phase 4 — Item Details

- [x] Categories: EDIBLE, CONSUMABLE, CLOTHING, BAG_LUGGAGE, ELECTRONICS, MISC
- [x] Quantity, units, min quantity
- [x] Price, currency, purchase date
- [ ] Owner assignment
- [x] Expiration date
- [ ] Category-specific attributes (`item_category_attributes`)

---

## Phase 5 — Images and Barcode

- [x] Schema: `images`, `item_barcodes`
- [x] Camera primary; gallery secondary
- [ ] Crop / resize; EXIF GPS strip (basic resize via image_picker quality/max dims)
- [x] Private Storage bucket + signed URLs
- [x] Barcode scan → lookup / attach to item
- [ ] Internal QR labels

---

## Phase 6 — Inventory Transactions

- [ ] Schema: `inventory_transactions`, `products`, `product_containers`
- [ ] INITIAL_STOCK, USE, RESTOCK, ADJUSTMENT, DISPOSE
- [ ] TRANSFER_REFILL (total stock unchanged)
- [ ] Atomic trusted functions; no silent negative quantities
- [ ] Transaction history UI

---

## Phase 7 — Predictions

- [ ] Schema: `consumption_predictions`
- [ ] Active-container refill forecast
- [ ] Total-stock depletion forecast
- [ ] Confidence labels and explanations
- [ ] Exclude refill transfers from consumption

---

## Phase 8 — Packing and Unpacking

- [ ] Schema: `trips`, `trip_containers`, `trip_items`, packing templates
- [ ] Assign mobile containers to Trips
- [ ] Pack with original location capture
- [ ] Selective unpack / return to original
- [ ] Completion check for unconfirmed items

---

## Phase 9 — Notifications

- [ ] Schema: notifications, preferences, device tokens
- [ ] In-app notification center (source of truth)
- [ ] FCM via Edge Function
- [ ] Quiet hours + preview privacy

---

## Phase 10 — Search and Dashboard

- [ ] Global / room / container search
- [ ] Filters
- [ ] Dashboard: expiring, low stock, predicted depletion, active Trips, recent activity

---

## Phase 11 — Quality and Release

- [ ] Unit, integration, authorization, performance tests
- [ ] Crash reporting
- [ ] Accessibility review
- [ ] Internal Android testing
- [ ] Play Store preparation

---

## MVP include list (planning §41.1)

Google SSO · profiles · multi-Home · invites · roles · rooms · inventory nodes · nested containers · item-as-container · categories · quantity/units · price/currency/purchase date · expiration · images · barcode · use/restock/refill · search · move · basic predictions · packing · templates · in-app + Android push · audit history · private images · RLS tests · archive-over-delete

## Explicitly post-MVP

Full offline sync · seasonality · AI recognition · receipt OCR · auto barcode product lookup · multi-batch expiration · warranty · airline baggage rules · lending · messaging · NFC · smart home · insurance reports · shopping integrations · depreciation · iOS · web dashboard
