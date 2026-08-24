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

- **Add several names** sheet: paste or type one name per line (commas/semicolons also split). Each line becomes an `ITEM` in the current room or container. Details (photo, qty, barcode) stay on the single-item form.
- Create form: **Save & add another** keeps the editor on the form after insert.

CSV import is not in the client.

### Multi-select

- **Desktop web:** checkbox on inventory cards for editors.
- **Phone / mobile web:** long-press a card to enter selection mode; further taps toggle. Checkboxes appear while selecting.
- Overflow **Select** on browse cards is an extra affordance.
- Selection bar: **Move**, **Pack**, **Dispose**, clear.

Move reuses `move_inventory_node` (top-most selected nodes only, so a parent is not followed by its already-nested child). Dispose reuses `apply_inventory_transaction` (`DISPOSE`). Pack reuses `add_items_to_packing_plan` for `ITEM` nodes onto a planned/active trip bag.

---

## Rationale

- Names-in-place matches how people dump a drawer into the app; a spreadsheet importer would ignore containment.
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

Client loops existing RPCs; `createItemsFromNames` / `moveNodes` / `disposeNodes` are repository helpers only.

---

## UI Impact

- Room/container app bar: playlist-add for several names.
- Create object: Save & add another.
- Inventory cards: checkbox / long-press; bottom selection bar.

---

## References

- [`mobile/lib/shared/widgets/inventory_row_card.dart`](../../mobile/lib/shared/widgets/inventory_row_card.dart)
- [`mobile/lib/shared/widgets/selection_action_bar.dart`](../../mobile/lib/shared/widgets/selection_action_bar.dart)
- [ADR-0008](0008-inventory-transactions.md), [ADR-0009](0009-trips-packing.md), [ADR-0011](0011-flutter-web-github-pages.md)
