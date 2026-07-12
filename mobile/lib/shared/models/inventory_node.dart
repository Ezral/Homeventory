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
    this.itemCategory,
    this.quantity,
    this.quantityUnit,
    this.minimumQuantity,
    this.purchasePrice,
    this.currency,
    this.purchaseDate,
    this.expirationDate,
    this.brand,
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
  final ItemCategory? itemCategory;
  final double? quantity;
  final String? quantityUnit;
  final double? minimumQuantity;
  final double? purchasePrice;
  final String? currency;
  final DateTime? purchaseDate;
  final DateTime? expirationDate;
  final String? brand;
  final String createdByUserId;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;

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
        'item_category': itemCategory?.dbValue,
        'quantity': quantity,
        'quantity_unit': quantityUnit,
        'minimum_quantity': minimumQuantity,
        'purchase_price': purchasePrice,
        'currency': currency,
        'purchase_date': purchaseDate?.toIso8601String().split('T').first,
        'expiration_date': expirationDate?.toIso8601String().split('T').first,
        'brand': brand,
        'created_by_user_id': createdByUserId,
      };
}
