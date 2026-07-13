import 'enums.dart';

class InventoryNode {
  const InventoryNode({
    required this.id,
    required this.homeId,
    required this.roomId,
    this.parentNodeId,
    required this.nodeKind,
    required this.name,
    this.description,
    this.isContainer = false,
    this.isMobileContainer = false,
    this.isDisposed = false,
    this.disposedAt,
    this.isDispenser = false,
    this.dispenserMode,
    this.isDispensable = false,
    this.consumableForm,
    this.capacity,
    this.itemCategory,
    this.quantity,
    this.quantityUnit,
    this.minimumQuantity,
    this.purchasePrice,
    this.currency,
    this.purchaseDate,
    this.expirationDate,
    this.brand,
    this.weight,
    this.weightUnit,
    required this.createdByUserId,
    this.archivedAt,
  });

  final String id;
  final String homeId;
  final String roomId;
  final String? parentNodeId;
  final InventoryNodeKind nodeKind;
  final String name;
  final String? description;
  final bool isContainer;
  final bool isMobileContainer;
  final bool isDisposed;
  final DateTime? disposedAt;
  final bool isDispenser;
  final DispenserMode? dispenserMode;
  final bool isDispensable;
  final ConsumableForm? consumableForm;
  final double? capacity;
  final ItemCategory? itemCategory;
  final double? quantity;
  final String? quantityUnit;
  final double? minimumQuantity;
  final double? purchasePrice;
  final String? currency;
  final DateTime? purchaseDate;
  final DateTime? expirationDate;
  final String? brand;
  final double? weight;
  final String? weightUnit;
  final String createdByUserId;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;

  DispenserMode get effectiveDispenserMode =>
      dispenserMode ?? DispenserMode.single;

  String get kindLabel {
    if (isMobileContainer) return 'Mobile container';
    if (isContainer && nodeKind == InventoryNodeKind.item) {
      return 'Item + container';
    }
    return nodeKind.label;
  }

  factory InventoryNode.fromJson(Map<String, dynamic> json) {
    return InventoryNode(
      id: json['id'] as String,
      homeId: json['home_id'] as String,
      roomId: json['room_id'] as String,
      parentNodeId: json['parent_node_id'] as String?,
      nodeKind: InventoryNodeKind.fromDb(json['node_kind'] as String),
      name: json['name'] as String,
      description: json['description'] as String?,
      isContainer: json['is_container'] as bool? ?? false,
      isMobileContainer: json['is_mobile_container'] as bool? ?? false,
      isDisposed: json['is_disposed'] as bool? ?? false,
      disposedAt: json['disposed_at'] != null
          ? DateTime.tryParse(json['disposed_at'] as String)
          : null,
      isDispenser: json['is_dispenser'] as bool? ?? false,
      dispenserMode: json['dispenser_mode'] == null
          ? null
          : DispenserMode.fromDb(json['dispenser_mode'] as String),
      isDispensable: json['is_dispensable'] as bool? ?? false,
      consumableForm: ConsumableForm.fromDb(json['consumable_form'] as String?),
      capacity: (json['capacity'] as num?)?.toDouble(),
      itemCategory: ItemCategory.fromDb(json['item_category'] as String?),
      quantity: (json['quantity'] as num?)?.toDouble(),
      quantityUnit: json['quantity_unit'] as String?,
      minimumQuantity: (json['minimum_quantity'] as num?)?.toDouble(),
      purchasePrice: (json['purchase_price'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      purchaseDate: json['purchase_date'] != null
          ? DateTime.tryParse(json['purchase_date'] as String)
          : null,
      expirationDate: json['expiration_date'] != null
          ? DateTime.tryParse(json['expiration_date'] as String)
          : null,
      brand: json['brand'] as String?,
      weight: (json['weight'] as num?)?.toDouble(),
      weightUnit: json['weight_unit'] as String?,
      createdByUserId: json['created_by_user_id'] as String,
      archivedAt: json['archived_at'] != null
          ? DateTime.tryParse(json['archived_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertJson({required String createdByUserId}) => {
    'home_id': homeId,
    'room_id': roomId,
    'parent_node_id': parentNodeId,
    'node_kind': nodeKind.dbValue,
    'name': name,
    'description': description,
    'is_container': isContainer,
    'is_mobile_container': isMobileContainer,
    'is_disposed': isDisposed,
    'disposed_at': disposedAt?.toIso8601String(),
    'is_dispenser': isDispenser,
    'dispenser_mode': isDispenser
        ? (dispenserMode ?? DispenserMode.single).dbValue
        : null,
    'is_dispensable': isDispensable,
    'consumable_form': consumableForm?.dbValue,
    'capacity': capacity,
    'item_category': itemCategory?.dbValue,
    'quantity': quantity,
    'quantity_unit': quantityUnit,
    'minimum_quantity': minimumQuantity,
    'purchase_price': purchasePrice,
    'currency': currency,
    'purchase_date': purchaseDate?.toIso8601String().split('T').first,
    'expiration_date': expirationDate?.toIso8601String().split('T').first,
    'brand': brand,
    'weight': weight,
    'weight_unit': weightUnit,
    'created_by_user_id': createdByUserId,
  };
}

class DispenserProductAssignment {
  const DispenserProductAssignment({
    required this.id,
    required this.homeId,
    required this.dispenserItemId,
    required this.productItemId,
    required this.slotNumber,
    this.capacity,
    this.quantity = 0,
    this.quantityUnit,
    this.productName,
  });

  final String id;
  final String homeId;
  final String dispenserItemId;
  final String productItemId;
  final int slotNumber;
  final double? capacity;
  final double quantity;
  final String? quantityUnit;
  final String? productName;

  String get fillLabel {
    final unit = quantityUnit?.trim().isNotEmpty == true ? quantityUnit! : 'CC';
    final qty = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toString();
    if (capacity == null) return '$qty $unit';
    final cap = capacity == capacity!.roundToDouble()
        ? capacity!.toInt().toString()
        : capacity.toString();
    return '$qty / $cap $unit';
  }

  factory DispenserProductAssignment.fromJson(Map<String, dynamic> json) {
    return DispenserProductAssignment(
      id: json['id'] as String,
      homeId: json['home_id'] as String,
      dispenserItemId: json['dispenser_item_id'] as String,
      productItemId: json['product_item_id'] as String,
      slotNumber: (json['slot_number'] as num).toInt(),
      capacity: (json['capacity'] as num?)?.toDouble(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      quantityUnit: json['quantity_unit'] as String?,
      productName: json['product_name'] as String?,
    );
  }
}
