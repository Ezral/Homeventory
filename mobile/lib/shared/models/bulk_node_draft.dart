import 'dart:typed_data';

import 'enums.dart';
import 'inventory_node.dart';

/// Room + optional parent container where a bulk-add row will be created.
class BulkPlacement {
  const BulkPlacement({
    required this.roomId,
    this.parentNodeId,
    this.label = '',
  });

  final String roomId;
  final String? parentNodeId;
  final String label;

  @override
  bool operator ==(Object other) {
    return other is BulkPlacement &&
        other.roomId == roomId &&
        other.parentNodeId == parentNodeId;
  }

  @override
  int get hashCode => Object.hash(roomId, parentNodeId);
}

/// `Kitchen` or `Kitchen › Closet › Drawer`.
String formatBulkPlacementLabel({
  required String roomName,
  List<String> containerNames = const [],
}) {
  final parts = [
    roomName.trim(),
    for (final name in containerNames)
      if (name.trim().isNotEmpty) name.trim(),
  ].where((part) => part.isNotEmpty);
  return parts.join(' › ');
}

({String roomId, String? parentNodeId}) bulkCreateTarget({
  required BulkNodeDraft draft,
  required String fallbackRoomId,
  String? fallbackParentNodeId,
}) {
  final placement = draft.placement;
  if (placement == null) {
    return (roomId: fallbackRoomId, parentNodeId: fallbackParentNodeId);
  }
  return (roomId: placement.roomId, parentNodeId: placement.parentNodeId);
}

/// Parent container for Add / Add several from the current browse view.
///
/// The list's [listParentNodeId] is the room (null) or the container whose
/// contents occupy the left list. On desktop, selecting furniture or drilling
/// into nested storage should nest new items in that viewed container instead.
String? bulkAddParentId({
  required String? listParentNodeId,
  String? selectedId,
  bool selectedIsContainer = false,
  List<String> nestedContainerPath = const [],
  String? nestedItemId,
}) {
  if (nestedContainerPath.isNotEmpty) return nestedContainerPath.last;
  if (selectedIsContainer && selectedId != null) return selectedId;
  return listParentNodeId;
}

/// A photo attached to a bulk-add / bulk-edit row, uploaded on save.
class BulkPendingPhoto {
  const BulkPendingPhoto({
    required this.bytes,
    required this.mimeType,
    this.extension = 'jpg',
  });

  final Uint8List bytes;
  final String mimeType;
  final String extension;
}

/// One row in the bulk-add table before it is saved.
class BulkNodeDraft {
  const BulkNodeDraft({
    required this.name,
    this.type = InventoryTypeChoice.item,
    this.quantity,
    this.purchasePrice,
    this.brand,
    this.weight,
    this.weightUnit,
    this.photos = const [],
    this.placement,
  });

  final String name;
  final InventoryTypeChoice type;
  final double? quantity;
  final double? purchasePrice;
  final String? brand;
  final double? weight;
  final String? weightUnit;
  final List<BulkPendingPhoto> photos;
  final BulkPlacement? placement;

  bool get isItemLike => type.isItemLike;

  factory BulkNodeDraft.fromNode(InventoryNode node) {
    return BulkNodeDraft(
      name: node.name,
      type: InventoryTypeChoice.fromNode(
        nodeKind: node.nodeKind,
        itemCategory: node.itemCategory,
      ),
      quantity: node.quantity,
      purchasePrice: node.purchasePrice,
      brand: node.brand,
      weight: node.weight,
      weightUnit: node.weightUnit,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BulkNodeDraft &&
        other.name == name &&
        other.type == type &&
        other.quantity == quantity &&
        other.purchasePrice == purchasePrice &&
        other.brand == brand &&
        other.weight == weight &&
        other.weightUnit == weightUnit &&
        other.placement == placement;
  }

  @override
  int get hashCode => Object.hash(
    name,
    type,
    quantity,
    purchasePrice,
    brand,
    weight,
    weightUnit,
    placement,
  );

  BulkNodeDraft copyWith({
    String? name,
    InventoryTypeChoice? type,
    double? quantity,
    bool clearQuantity = false,
    double? purchasePrice,
    bool clearPurchasePrice = false,
    String? brand,
    bool clearBrand = false,
    double? weight,
    bool clearWeight = false,
    String? weightUnit,
    List<BulkPendingPhoto>? photos,
    BulkPlacement? placement,
    bool clearPlacement = false,
  }) {
    return BulkNodeDraft(
      name: name ?? this.name,
      type: type ?? this.type,
      quantity: clearQuantity ? null : (quantity ?? this.quantity),
      purchasePrice: clearPurchasePrice
          ? null
          : (purchasePrice ?? this.purchasePrice),
      brand: clearBrand ? null : (brand ?? this.brand),
      weight: clearWeight ? null : (weight ?? this.weight),
      weightUnit: weightUnit ?? this.weightUnit,
      photos: photos ?? this.photos,
      placement: clearPlacement ? null : (placement ?? this.placement),
    );
  }
}

/// Fields to apply onto selected bulk-add rows or existing nodes.
class BulkNodePatch {
  const BulkNodePatch({
    this.type,
    this.quantity,
    this.applyQuantity = false,
    this.purchasePrice,
    this.applyPrice = false,
    this.brand,
    this.applyBrand = false,
    this.weight,
    this.applyWeight = false,
    this.weightUnit,
    this.placement,
    this.applyPlacement = false,
  });

  final InventoryTypeChoice? type;
  final double? quantity;
  final bool applyQuantity;
  final double? purchasePrice;
  final bool applyPrice;
  final String? brand;
  final bool applyBrand;
  final double? weight;
  final bool applyWeight;
  final String? weightUnit;
  final BulkPlacement? placement;
  final bool applyPlacement;

  bool get hasChanges =>
      type != null ||
      applyQuantity ||
      applyPrice ||
      applyBrand ||
      applyWeight ||
      applyPlacement;
}

/// Shared vs mixed values across a checked set.
class SharedBulkValues {
  const SharedBulkValues({
    this.type,
    this.typeMixed = false,
    this.quantity,
    this.quantityMixed = false,
    this.purchasePrice,
    this.priceMixed = false,
    this.brand,
    this.brandMixed = false,
    this.weight,
    this.weightMixed = false,
    this.placement,
    this.placementMixed = false,
  });

  final InventoryTypeChoice? type;
  final bool typeMixed;
  final double? quantity;
  final bool quantityMixed;
  final double? purchasePrice;
  final bool priceMixed;
  final String? brand;
  final bool brandMixed;
  final double? weight;
  final bool weightMixed;
  final BulkPlacement? placement;
  final bool placementMixed;
}

/// Parses quantity / price / weight cells. Blank or unreadable text is omitted.
double? parseOptionalNumber(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim().replaceAll(',', '');
  if (trimmed.isEmpty) return null;
  return double.tryParse(trimmed);
}

String? formatOptionalNumber(double? value) {
  if (value == null) return null;
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}

String? _normBrand(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
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
          brand: _normBrand(draft.brand),
          weight: draft.weight,
          weightUnit: draft.weight != null
              ? (draft.weightUnit ?? 'g')
              : draft.weightUnit,
          photos: draft.photos,
          placement: draft.placement,
        ),
  ];
}

SharedBulkValues sharedValuesFromDrafts(List<BulkNodeDraft> drafts) {
  return _shared(
    types: drafts.map((d) => d.type),
    quantities: drafts.map((d) => d.quantity),
    prices: drafts.map((d) => d.purchasePrice),
    brands: drafts.map((d) => _normBrand(d.brand)),
    weights: drafts.map((d) => d.weight),
    placements: drafts.map((d) => d.placement),
  );
}

SharedBulkValues sharedValuesFromNodes(List<InventoryNode> nodes) {
  return _shared(
    types: nodes.map(
      (n) => InventoryTypeChoice.fromNode(
        nodeKind: n.nodeKind,
        itemCategory: n.itemCategory,
      ),
    ),
    quantities: nodes.map((n) => n.quantity),
    prices: nodes.map((n) => n.purchasePrice),
    brands: nodes.map((n) => _normBrand(n.brand)),
    weights: nodes.map((n) => n.weight),
    placements: nodes.map((_) => null),
  );
}

SharedBulkValues _shared({
  required Iterable<InventoryTypeChoice> types,
  required Iterable<double?> quantities,
  required Iterable<double?> prices,
  required Iterable<String?> brands,
  required Iterable<double?> weights,
  required Iterable<BulkPlacement?> placements,
}) {
  final typeList = types.toList();
  final qtyList = quantities.toList();
  final priceList = prices.toList();
  final brandList = brands.toList();
  final weightList = weights.toList();
  final placementList = placements.toList();
  if (typeList.isEmpty) return const SharedBulkValues();

  bool mixed<T>(List<T> values) => values.any((v) => v != values.first);

  return SharedBulkValues(
    typeMixed: mixed(typeList),
    type: mixed(typeList) ? null : typeList.first,
    quantityMixed: mixed(qtyList),
    quantity: mixed(qtyList) ? null : qtyList.first,
    priceMixed: mixed(priceList),
    purchasePrice: mixed(priceList) ? null : priceList.first,
    brandMixed: mixed(brandList),
    brand: mixed(brandList) ? null : brandList.first,
    weightMixed: mixed(weightList),
    weight: mixed(weightList) ? null : weightList.first,
    placementMixed: mixed(placementList),
    placement: mixed(placementList) ? null : placementList.first,
  );
}

List<BulkNodeDraft> applyPatchToDrafts({
  required List<BulkNodeDraft> drafts,
  required BulkNodePatch patch,
  required Set<int> selectedIndices,
}) {
  final applyAll = selectedIndices.isEmpty;
  return [
    for (var i = 0; i < drafts.length; i++)
      if (applyAll || selectedIndices.contains(i))
        drafts[i].copyWith(
          type: patch.type,
          quantity: patch.applyQuantity ? patch.quantity : null,
          clearQuantity: patch.applyQuantity && patch.quantity == null,
          purchasePrice: patch.applyPrice ? patch.purchasePrice : null,
          clearPurchasePrice: patch.applyPrice && patch.purchasePrice == null,
          brand: patch.applyBrand ? patch.brand : null,
          clearBrand:
              patch.applyBrand && (patch.brand == null || patch.brand!.isEmpty),
          weight: patch.applyWeight ? patch.weight : null,
          clearWeight: patch.applyWeight && patch.weight == null,
          weightUnit: patch.applyWeight ? (patch.weightUnit ?? 'g') : null,
          placement: patch.applyPlacement ? patch.placement : null,
          clearPlacement: patch.applyPlacement && patch.placement == null,
        )
      else
        drafts[i],
  ];
}

/// Sets [type] on checked rows. With nothing checked, every row updates.
List<BulkNodeDraft> applyTypeToDrafts({
  required List<BulkNodeDraft> drafts,
  required InventoryTypeChoice type,
  required Set<int> selectedIndices,
}) {
  return applyPatchToDrafts(
    drafts: drafts,
    patch: BulkNodePatch(type: type),
    selectedIndices: selectedIndices,
  );
}
