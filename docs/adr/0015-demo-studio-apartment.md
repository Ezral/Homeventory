# ADR-0015

Bundled Bangkok demo studio

## Status

Accepted

## Date

2026-08-26

---

## Context

Demos need a furnished home that matches a real 24 m² Bangkok studio: three rooms, nested furniture, prices in THB, and photos of that apartment. Spreadsheet rows and generated apartment images already exist. Hosted Postgres must not receive a shared seed home (RLS is membership-based; `supabase/seed.sql` is local-only).

## Decision

Ship a **client-side installer**. After sign-in, **Your homes** creates **Bangkok studio** if that home is not already in the list (timezone `Asia/Bangkok`, currency THB). The same action is also a **Demo studio** control. The app reads bundled `assets/demo_studio/catalog.json` and the six apartment JPEGs, then uploads photos through the existing private `home-images` bucket. The signed-in user is `created_by_user_id` and therefore **OWNER**.

Inventory follows ADR-0005:

- Rooms: Studio, Kitchen, Bathroom
- Spreadsheet `furniture` → `FURNITURE` containers
- Spreadsheet `clothing` → `ITEM` + `CLOTHING`
- Spreadsheet `item` → `ITEM`, with edible / consumable / electronics when obvious
- Location paths become parent nodes (wardrobe sections, cabinet drawers, fridge)

The spreadsheet remains at [`docs/demo/Homeventory_Demo_Studio_Inventory.xlsx`](../demo/Homeventory_Demo_Studio_Inventory.xlsx) as the source list (68 entries, ฿213,925).

## Rationale

- Each demoist gets their own home under their Google user; no shared production fixture.
- Photos stay private like any other household image.
- Re-running the action creates another copy, which is fine for a second walkthrough.

## Alternatives Considered

1. **SQL seed on hosted Supabase** — rejected: would be a global home or require a service-role insert outside RLS.
2. **Hard-coded Dart tree** — rejected: the Excel list is the source; JSON stays diffable and testable.

## Consequences

### Advantages

- One tap from an empty (or existing) homes list.
- Drill-down in the studio matches the apartment photos.

### Disadvantages

- Install uploads many images; it takes a short wait on first load.
- Catalog and spreadsheet can drift if only one is edited.

## Security Impact

Uses the same `createHome` / `createRoom` / `createNode` / image upload paths as manual entry. No new RLS. Bundled photos are not personal data.

## Database Impact

None. No migration.

## UI Impact

- Homes list: **Demo studio** control; auto-creates **Bangkok studio** when missing
- Empty homes list: **Load demo studio**

## References

- [`mobile/assets/demo_studio/`](../../mobile/assets/demo_studio/)
- [`mobile/lib/features/homes/data/demo_studio_installer.dart`](../../mobile/lib/features/homes/data/demo_studio_installer.dart)
- [ADR-0005](0005-recursive-inventory-nodes.md), [ADR-0006](0006-private-images-and-barcodes.md)
