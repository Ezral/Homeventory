# ADR-0006

Private images Storage and item barcodes

## Status

Accepted

## Date

2026-07-12

---

## Context

Users need photos of belongings and barcode attach/lookup. Images must not be world-readable. Barcodes must be unique per Home and searchable.

---

## Decision

### Images

- Metadata table `images` with `home_id`, `entity_type` (`HOME` | `ROOM` | `INVENTORY_NODE`), `entity_id`, `storage_path`, mime/size, `uploaded_by_user_id`.
- Private Storage bucket **`home-images`** (not public), 10 MB limit, image MIME allow-list.
- Object path convention: `{home_id}/{entity_type}/{entity_id}/{uuid}.ext`
- Helper `storage_home_id(name)` parses the first path segment as UUID for Storage RLS.
- Storage + table policies: members can read; editors can write/delete.
- Client uploads via `uploadBinary`, inserts metadata, displays **signed URLs** (1 hour) on node detail.
- Flutter: `image_picker` (camera primary in UI sheet order, gallery secondary); basic downscale via picker `maxWidth`/`maxHeight`/`imageQuality`.

### Barcodes

- Table `item_barcodes`: `home_id`, `inventory_node_id`, `barcode_value`, optional `barcode_format`, `is_primary`.
- Unique `(home_id, barcode_value)`.
- RLS via `can_view_home` / `can_edit_inventory`.
- Client: `mobile_scanner` screen returns a string; node detail can scan or manual-enter; search resolves barcode matches to nodes.
- CAMERA permission declared on Android.

Internal QR label generation and “create item from unknown barcode” flows are **not** implemented.

---

## Rationale

- **Security:** Private bucket + path-scoped RLS + signed URLs avoids public CDN exposure of household photos.
- **Simplicity:** Polymorphic `images` table covers home/room/node without three nearly identical tables.
- **Productivity:** Supabase Storage avoids a separate media service.

---

## Alternatives Considered

1. **Public bucket with obscure URLs**  
   Rejected: URLs leak; household photos are sensitive.

2. **Store image bytes in Postgres**  
   Rejected: poor fit for large binaries and CDN-style delivery.

3. **Barcode value only on `inventory_nodes`**  
   Rejected: planning and real goods allow multiple barcodes per item.

4. **Client-only barcode cache**  
   Rejected: must be Home-scoped and collaborative.

---

## Consequences

### Advantages

- Editors can attach multiple photos and barcodes per node.
- Search can find items by barcode value without a separate search engine.

### Disadvantages

- Signed URLs expire; long-lived screens may show broken images until refresh.
- No server-side EXIF GPS strip / crop pipeline yet (client resize only).
- `entity_type`/`entity_id` are not FK-enforced to homes/rooms/nodes (polymorphic).

---

## Security Impact

- Storage policies require valid UUID home segment and membership/edit checks.
- Image insert requires `uploaded_by_user_id = auth.uid()`.
- Barcode uniqueness is per Home, not global.

---

## Database Impact

Migration: `20260712000400_images_barcodes.sql`

- Tables: `images`, `item_barcodes`
- Bucket: `home-images`
- Function: `storage_home_id`
- Grants on both tables to `authenticated`

---

## API Impact

- Storage upload/remove + `createSignedUrl`.
- PostgREST on `images` / `item_barcodes`.
- No Edge Function image processor.

---

## UI Impact

- Node detail: Photos and Barcodes sections.
- Search app bar: scan barcode action; query field accepts name or barcode text.
- Route: `/homes/:homeId/scan-barcode`.

---

## Future Considerations

- Crop / EXIF scrubbing service.
- Cover image linkage for homes/rooms (`cover_image_id` / `image_id` columns already exist).
- Unknown barcode → create item quick action.

---

## Architecture Notes

- Polymorphic images lack referential integrity — orphan metadata possible if entity deleted without cascading image cleanup (inventory delete/archive does not auto-remove storage objects today).
- `storage_home_id` returns null for non-UUID paths; policies require non-null — good.
- HEIC listed in bucket MIME allow-list; client upload path currently favors jpeg/png/webp extensions.

---

## References

- [`supabase/migrations/20260712000400_images_barcodes.sql`](../../supabase/migrations/20260712000400_images_barcodes.sql)
- [`mobile/lib/features/inventory/data/inventory_repository.dart`](../../mobile/lib/features/inventory/data/inventory_repository.dart)
- [`mobile/lib/features/inventory/presentation/node_detail_screen.dart`](../../mobile/lib/features/inventory/presentation/node_detail_screen.dart)
- [`mobile/lib/features/inventory/presentation/barcode_scan_screen.dart`](../../mobile/lib/features/inventory/presentation/barcode_scan_screen.dart)
- PR: [#12](https://github.com/Ezral/Homeventory/pull/12)
- Related: [ADR-0005](0005-recursive-inventory-nodes.md)
