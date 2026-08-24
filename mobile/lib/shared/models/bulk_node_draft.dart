import 'enums.dart';

/// One row in the bulk-add table before it is saved.
class BulkNodeDraft {
  const BulkNodeDraft({
    required this.name,
    this.type = InventoryTypeChoice.item,
    this.quantity,
    this.purchasePrice,
  });

  final String name;
  final InventoryTypeChoice type;
  final double? quantity;
  final double? purchasePrice;

  bool get isItemLike => type.isItemLike;

  @override
  bool operator ==(Object other) {
    return other is BulkNodeDraft &&
        other.name == name &&
        other.type == type &&
        other.quantity == quantity &&
        other.purchasePrice == purchasePrice;
  }

  @override
  int get hashCode => Object.hash(name, type, quantity, purchasePrice);

  BulkNodeDraft copyWith({
    String? name,
    InventoryTypeChoice? type,
    double? quantity,
    bool clearQuantity = false,
    double? purchasePrice,
    bool clearPurchasePrice = false,
  }) {
    return BulkNodeDraft(
      name: name ?? this.name,
      type: type ?? this.type,
      quantity: clearQuantity ? null : (quantity ?? this.quantity),
      purchasePrice: clearPurchasePrice
          ? null
          : (purchasePrice ?? this.purchasePrice),
    );
  }
}

/// Parses quantity / price cells. Blank or unreadable text is omitted.
double? parseOptionalNumber(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim().replaceAll(',', '');
  if (trimmed.isEmpty) return null;
  return double.tryParse(trimmed);
}

/// Drops blank names and trims the rest, in table order.
List<BulkNodeDraft> namedBulkDrafts(Iterable<BulkNodeDraft> drafts) {
  return [
    for (final draft in drafts)
      if (draft.name.trim().isNotEmpty)
        BulkNodeDraft(
          name: draft.name.trim(),
          type: draft.type,
          quantity: draft.quantity,
          purchasePrice: draft.purchasePrice,
        ),
  ];
}

/// Sets [type] on checked rows. With nothing checked, every row updates.
List<BulkNodeDraft> applyTypeToDrafts({
  required List<BulkNodeDraft> drafts,
  required InventoryTypeChoice type,
  required Set<int> selectedIndices,
}) {
  final applyAll = selectedIndices.isEmpty;
  return [
    for (var i = 0; i < drafts.length; i++)
      if (applyAll || selectedIndices.contains(i))
        drafts[i].copyWith(type: type)
      else
        drafts[i],
  ];
}
