# ADR-0012

Inventory bulk add and multi-select actions

## Status

Accepted

## Date

2026-08-24

---

## Context

Editors needed a fast way to capture many item names in the current location, and to act on several existing objects at once (move, dispose, pack) from browse and search.

---

## Decision

### Bulk input

- **Add several** dialog (desktop) / fullscreen page (phone): table of **Name**, **Type**, **Qty**, **Price**, **Brand**, **Weight**, **Photo**. Type is furniture / storage / item / **clothing**. Clothing is stored as an `ITEM` with category `CLOTHING`. Check rows to bulk-edit shared fields (type, quantity, price, brand, weight); mixed values show as Mixed and stay unchanged if left blank. With none checked, Apply updates every row. Blank names are skipped. Each row can attach one or more photos (camera or gallery); they upload when the table is saved. Other details (barcodes, dates) stay on the single-item form. On the create/edit form, Type can be changed after create, including Item → Furniture. Switching to furniture or storage clears item category and marks the node as a container. New rows default to the **container currently being viewed** (furniture, mini-storage, or nested storage on desktop); a location picker can still override that.
- Create form: **Save & add another** keeps the editor on the form after insert.

CSV import is not in the client.

### Multi-select

- **Desktop web:** checkbox on inventory cards for editors.
- **Phone / mobile web:** long-press a card to enter selection mode; further taps toggle. Checkboxes appear while selecting.
- Overflow **Select** on browse cards is an extra affordance.
- Selection bar: **Edit**, **Move**, **Pack**, **Dispose**, clear. Edit opens a table with **one row per selected item**, prefilled so each can be changed individually, including per-row photos saved together.

Move reuses `move_inventory_node` (top-most selected nodes only, so a parent is not followed by its already-nested child). Dispose reuses `apply_inventory_transaction` (`DISPOSE`). Pack reuses `add_items_to_packing_plan` for `ITEM` nodes onto a planned/active trip bag.

---

## Rationale

- A small table in the current location is enough for mixed furniture/storage/items with qty and price; a spreadsheet importer would still ignore containment.
- Platform-native selection (checkbox vs long-press) matches the desktop/mobile chrome already in ADR-0011.
- Existing RPCs keep authorization in Postgres.

---

## Alternatives Considered

1. **CSV / spreadsheet import** — rejected for this slice; no location mapping UI.
2. **Hard delete** — rejected; product uses dispose (ADR-0008).
3. **New batch SQL RPC** — not required; sequential trusted RPCs are enough at household scale.

---

## Consequences

### Advantages

- Same cards in room browse and search support selection.
- Packing from search/browse uses the trip plan overlay (inventory stays put).

### Disadvantages

- Sequential RPCs can partially succeed if a later call fails.

---

## Security Impact

UI is editor-gated. RLS/RPCs remain authoritative (`can_edit_inventory`).

---

## Database Impact

None.

---

## API Impact

Client loops existing RPCs; `createBulkNodes` / `updateBulkNodes` / `moveNodes` / `disposeNodes` are repository helpers only.

---

## UI Impact

- Room/container app bar: playlist-add opens the bulk table.
- Create object: Save & add another.
- Inventory cards: checkbox / long-press; bottom selection bar.

---

## References

- [`mobile/lib/shared/widgets/bulk_add_dialog.dart`](../../mobile/lib/shared/widgets/bulk_add_dialog.dart)
- [`mobile/lib/shared/widgets/bulk_edit_dialog.dart`](../../mobile/lib/shared/widgets/bulk_edit_dialog.dart)
- [`mobile/lib/shared/widgets/inventory_row_card.dart`](../../mobile/lib/shared/widgets/inventory_row_card.dart)
- [`mobile/lib/shared/widgets/selection_action_bar.dart`](../../mobile/lib/shared/widgets/selection_action_bar.dart)
- [ADR-0008](0008-inventory-transactions.md), [ADR-0009](0009-trips-packing.md), [ADR-0011](0011-flutter-web-github-pages.md)
