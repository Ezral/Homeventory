# Phase 6-super UAT Follow-up Plan

Canonical planning update from **Phase 6-super UAT and product review**.

This document incorporates new requirements into the Homeventory roadmap. It does **not** replace [`Homeventory_Full_Planning.md`](Homeventory_Full_Planning.md); it amends and sequences work that must land **after** the shipped 6-super MVP.

| Related | Link |
| --- | --- |
| Shipped 6-super MVP checklist | [`PHASE_6_8_IMPLEMENTATION_PLAN.md`](PHASE_6_8_IMPLEMENTATION_PLAN.md) |
| Implementation backlog | [`IMPLEMENTATION.md`](IMPLEMENTATION.md) |
| Full product spec | [`Homeventory_Full_Planning.md`](Homeventory_Full_Planning.md) |

---

## Planning status

| Status | Meaning |
| --- | --- |
| **Locked for planning** | Requirements below are product decisions from UAT |
| **Not started (implementation)** | Schema/UI work still open unless noted as **partially shipped** |
| **Gate** | Room privacy / room RLS (Phase D+) should land before trusting dashboard totals and search for multi-member homes |

**Already partially shipped (do not re-build from zero):**

- Home edit UI (owner): name, description, address, timezone, currency, cover photo (`cover_image_id` + `images` entity `HOME`)
- Home cover on detail + list thumbnails
- Stock ledger, dispose, dispenser capacity MVP, Trips pack/unpack

**Phases A–C ship (this iteration):** `residing_since`, `remarks`, `updated_by`, residence duration label, wrapping home name, member avatars under name, decluttered header chips, cover remove + fallback, bottom nav (Search/Trips/Invite), user menu (Preferences + Sign out), dashboard RPC cards (rooms / base furniture / members / home-currency value stub). Invite default role → **VIEWER**.

**Still later (D+):** room-level RLS, room requests, temporary access, visibility, notifications/audit/loading polish.  
**Shipped since A–C:** home-currency FX dashboard sum (partial I); multi-dispenser slots (H); bottom nav `Search | Trips | Home | Invite | Add`.

---

## Phase numbering (post–6-super)

Existing backlog phases 1–8 (auth → predictions) stay as historical/shipped or deferred depth.  
**New ship sequence** uses letters to avoid colliding with old Phase 9–11 numbers:

| New phase | Scope | Depends on |
| --- | --- | --- |
| **A — Home profile** | Editable profile polish, residing date, remarks, members under name, image remove/fallback | Current home edit |
| **B — Shell navigation** | Bottom nav (Search / Trips / Invite), user menu, contextual FAB | A helpful but not hard |
| **C — Home dashboard** | Cards: rooms, base furniture, members, residence duration, estimated value (simple) | A; value may be home-currency-only until I |
| **D — Membership defaults + room permission foundation** | New members read-only; room-level role tables + RLS helpers | B/C UI can ship first; **RLS must land before privacy claims** |
| **E — Room requests + ownership / co-ownership** | Request → approve/reject; room owner / co-owner | D |
| **F — Room invitations + temporary access** | Permanent/temporary room invites; expiry-enforced access | D, E |
| **G — Room visibility + object inheritance** | Visible / restricted / private; object move checks; dashboard/search privacy | D–F |
| **H — Dispenser enhancement** | Single vs multi (1–3) product slots; dispensable products | 6-super dispenser MVP |
| **I — Currency + valuation + FX** | Home / item / display currencies; exchange_rates cache; dashboard value | C; **G for privacy-correct totals** |
| **J — Notifications, audit, loading polish, regression UAT** | In-app events, permission audit trail, page-ready loaders | E–I |

Map to UAT doc “Suggested Implementation Phasing” 1–10 → **A–J** above.

Deferred full Phase 6/7 polish and Phase 8 predictions remain in [`PHASE_6_8_IMPLEMENTATION_PLAN.md`](PHASE_6_8_IMPLEMENTATION_PLAN.md). Prefer finishing **A–C** before deep product-graph work unless UAT reorders.

---

# A — Home profile and dashboard shell content

## UAT feedback (summary)

Home page must act as a **profile + dashboard**, not only a navigation hub.

## Planned changes

| Feature | Planned behavior |
| --- | --- |
| Edit home | Authorized users edit name, image, residing date, remarks, location, home currency, and existing metadata |
| Home image | Camera/gallery upload, replace, **remove**, private storage, fallback image |
| Residing date | Store date household started residing |
| Residence duration | Derive at read time, e.g. `Living here for 2 years, 4 months` — **do not store age** |
| Home remarks | Optional multiline plain-text notes |
| Full home name | Wrap; do not ellipsize in header |
| Member display | Avatars/initials directly under home name |
| Declutter header | Do not show Owner / currency chips in the hero header (move to edit or secondary area) |

## Schema mapping (prefer existing columns)

| UAT field | Current / planned column | Notes |
| --- | --- | --- |
| `name` | `homes.name` | Exists |
| `image_path` | Prefer keep `cover_image_id` → `images` + signed URLs | Same private bucket pattern as rooms/nodes; avoid parallel path-only model unless ADR says otherwise |
| `residing_since` | **Add** `homes.residing_since date` | New |
| `remarks` | **Add** `homes.remarks text` **or** clarify vs `description` | Prefer new `remarks` for household notes; keep `description` as short blurb if both remain |
| `home_currency` | `homes.default_currency` | Alias in UI as “Home currency”; no rename required |
| `updated_at` | Exists | |
| `updated_by` | **Add** `homes.updated_by uuid` nullable → `profiles` | Optional but listed in UAT |

## Acceptance

- Authorized users can edit; unauthorized cannot (UI + RLS)
- Long names wrap without breaking layout
- Members appear under name
- Image from private storage; empty optional fields omit blank sections
- Residence duration recalculates from `residing_since`

---

# B — Navigation and page layout

| Area | Planned behavior |
| --- | --- |
| Bottom navigation | Search, Trips, Add/Invite user |
| User menu | Avatar top-right: identity, Preferences (placeholder), Sign out |
| Home FAB | Create room |
| Room FAB | Create object in **current** room (preselect home + room) |
| Preferences | Placeholder destination only |

## Acceptance

- Primary destinations reachable from bottom nav
- Avatar remains visible when home name wraps
- FAB is context-correct; object create inherits room context

---

# C — Dashboard metrics (initial)

| Card | Calculation |
| --- | --- |
| Rooms | Count active rooms **visible to current user** (until G, ≈ all home rooms for members) |
| Base furniture | Top-level furniture only (see definition below) |
| Members | Active authorized members |
| Estimated inventory value | Eligible item values in **display currency** (full rules in I; C may ship home-currency stub) |
| Residence duration | From `residing_since` |

### Base furniture definition

Count when node:

- Belongs directly to a room (`parent_node_id` null)
- Classified as furniture (`node_kind` / category rule TBD in ADR — likely `FURNITURE` kind)
- Active (not archived/disposed)
- No parent furniture/container

Do **not** count nested drawers, shelves, boxes, or ordinary items inside furniture.

### Efficiency

Prefer SQL aggregates / RPCs over loading every node into the client.

## Acceptance

- Top-level wardrobe increments count; nested drawer does not
- Archived/disposed excluded; unauthorized rooms excluded once G ships

---

# D — Home membership defaults and room permission foundation

## Permission model (target)

| Role | Default scope | Default rights |
| --- | --- | --- |
| Home owner | Entire home | Full control |
| Home member | Authorized areas | **Read-only** by default |
| Room owner | One room | Full operational control in room |
| Room co-owner | One room | Edit room contents |
| Room editor | One room | Create/edit room contents |
| Room viewer | One room | Read-only |
| Temporary room member | One room | Role until `expires_at` |

A user may be read-only at home level, co-owner of one room, viewer of another, and excluded from a private room.

**Breaking change vs today:** invites currently default to `EDITOR` with home-wide edit. New default membership must be **viewer / read-only** (exact enum TBD in ADR — map to existing `VIEWER` or rename “member”).

## Acceptance

- New member is read-only by default
- Cannot edit home unless authorized (owner/admin policy TBD)
- Room roles do not leak across rooms
- UI and RLS agree; unauthorized writes rejected

---

# E — Room creation requests + ownership / co-ownership

## Room request workflow

1. Member proposes name, description, image, reason, visibility, optional co-owners  
2. Pending — **no** room row yet  
3. Owner reviews / edits / approves / rejects  
4. Approve → create exactly one room; link `created_room_id`; requester becomes room owner or co-owner  
5. Reject → store reason; no room  
6. Duplicate protection: one request cannot create multiple rooms  

Atomic approve via RPC/transaction.

### Suggested table: `room_creation_requests`

Fields per UAT: `id`, `home_id`, `requested_by`, `proposed_name`, `proposed_description`, `proposed_image_path`, `request_reason`, `requested_visibility`, `status`, `reviewed_by`, `reviewed_at`, `rejection_reason`, `created_room_id`, `created_at`.

## Co-ownership rules

| Role | Room rights |
| --- | --- |
| Room owner | Edit room, contents, invite, permitted settings |
| Room co-owner | Edit room and contents |
| Room editor | Create/edit contents |
| Room viewer | Read-only |

Co-owner must **not** automatically: delete room, transfer primary ownership, change home settings, edit other rooms, assign more co-owners, remove home owner.

## Acceptance

- Read-only member can request; pending creates no room  
- Approve creates one room + scoped edit rights  
- Reject keeps history + reason  
- Assign/revoke co-owner; revoke restores underlying access without removing home membership  
- At least one responsible owner per room  

---

# F — Room invitations and temporary access

### `room_memberships` / `room_invitations`

Per UAT: roles, `access_type` permanent|temporary, `starts_at`, `expires_at`, `can_manage_members`, invite token/short code, revoke fields.

| Rule | Behavior |
| --- | --- |
| Permanent | Until revoked or leave |
| Temporary | Requires expiry; deny **immediately** after UTC expiry |
| Presets | 1 / 3 / 7 / 30 days + custom datetime |
| Audit | Expired/revoked rows retained |
| Cleanup job | May update status labels; **must not** be required for denial |

## Acceptance

- Invite to one room without exposing others  
- Viewer / editor / co-owner invite roles  
- Access stops at expiry and on revoke  

---

# G — Room visibility and object-level inheritance

| Visibility | Behavior |
| --- | --- |
| Visible to all home members | Listed; read-only unless room role |
| Restricted | Only selected members |
| Private | Home owner, room owner/co-owners, explicitly authorized |

Unauthorized users must not infer restricted rooms via: lists, search, counts, values, feeds, notifications, image paths, storage URLs, object counts.

### Object inheritance

Every object (furniture, items, nested nodes, images, barcodes, notes, dispenser links) inherits room access. Moves require edit in source **and** destination and destination visibility.

## Acceptance

- Hidden rooms absent from queries and aggregates  
- Storage RLS blocks unauthorized paths  
- Nested objects inherit room permissions  

---

# H — Dispenser enhancement

| Feature | Behavior |
| --- | --- |
| Single dispenser | Exactly one dispensable product |
| Multi dispenser | 1–3 products |
| Compatibility | Only `is_dispensable` products |
| Create product inline | Allowed during setup |
| Value | Linking must **not** double-count financial value |

### Suggested fields / tables

- Node/product: `dispenser_mode`, `is_dispensable`, `consumable_form`  
- `dispenser_product_assignments` (`dispenser_item_id`, `product_item_id`, `slot_number` 1–3, …)

Builds on 6-super `is_dispenser` + `capacity` + CC.

---

# I — Currency, valuation, exchange rates

Keep three concepts separate:

| Type | Purpose |
| --- | --- |
| Home currency | Home default (`default_currency`) |
| Item currency | Original recorded currency |
| Display currency | Dashboard reporting only — **never** overwrite home/item currency |

Initial display set: **IDR, THB, USD**.

Priority for display: user preference → home currency → USD.

### Valuation rules

- Preserve original price + currency + purchase date  
- `price_basis`: per unit vs total; multiply quantity only for per-unit  
- `include_in_home_value` opt-out  
- Aggregate by source currency, then convert subtotals  
- Decimal-safe numerics; round only for display  
- Show FX date + cached/stale disclosure  
- Unauthorized rooms excluded from visible total  

### `exchange_rates`

`base_currency`, `quote_currency`, `rate`, `rate_date`, `provider`, `retrieved_at`, `expires_at`.

Loading: use cache immediately; refresh stale in background; offline uses cache; no rate → show original-currency subtotals; never block whole dashboard on live FX.

---

# J — Notifications, audit, loading, regression UAT

## Notifications (in-app first)

Room invitation received/accepted/declined · temporary access near expiry / expired · room request submitted/approved/rejected · co-owner granted/revoked · room access revoked.

Must not leak private room details to unauthorized users.

## Audit trail

Permission and access events (invite create/accept/revoke, temp expiry, room request lifecycle, owner/co-owner/role/visibility changes) with acting/affected users, home/room, previous/new role, expiry, reason, timestamp. Not editable by normal members.

Complements 6-super `inventory_transactions` (stock) — this is **access/permission** audit.

## Page loading / images

- Initial navigation: full-page loader until required data + **initial viewport** images ready  
- Background refresh: small non-blocking indicator  
- Lazy-load offscreen images  
- Reuse valid cache on back navigation  
- Broken image placeholders; retry; avoid stuck/flashing loaders  
- FX refresh must not trigger full-page loader  

## Consolidated UAT checklist

Use the checklist in §16 of the source UAT brief (copied below as tracking list). Mark items in PRs as they pass.

### Home profile

- [ ] Edit home name  
- [ ] Upload / replace / remove home image  
- [ ] Set residing date; duration correct  
- [ ] Multiline remarks  
- [ ] Long names not truncated  
- [ ] Members under home name  

### Navigation

- [ ] Search, Trips, Add User in bottom nav  
- [ ] User avatar top-right; Preferences; Sign out  
- [ ] Home FAB → room; Room FAB → object in context  

### Membership / rooms / privacy / dispensers / dashboard / FX / loading

Track full §16 list during Phase D–J UAT; do not claim dashboard privacy until G.

---

## Post-MVP (explicitly out of A–J unless pulled forward)

Email/push · historical FX valuation · depreciation · market/insurance values · room ownership transfer workflow · temporary co-owner · custom permission profiles · dashboard charts · materialized summaries · scheduled expiry reminders · exportable valuation reports.

---

## Suggested PR / ADR cadence

| When | ADR / artifact |
| --- | --- |
| A | Home profile fields (`residing_since`, `remarks`, `updated_by`) |
| D | Room-level authorization model (replaces home-wide EDITOR default) |
| E | Room creation request RPC |
| F | Temporary access expiry enforcement |
| G | Room visibility + query privacy |
| H | Multi-dispenser assignments |
| I | Display currency vs home/item currency + FX cache |
| J | Notifications + permission audit_logs |

---

## Definition of ready (per letter phase)

A phase ship is ready when:

1. Schema + RLS (if any) + Flutter UI for that phase’s Must items  
2. SQL smoke for authorization-sensitive RPCs  
3. ADR updated when security/model changes  
4. APK version bumped  
5. Relevant UAT checklist rows marked  
