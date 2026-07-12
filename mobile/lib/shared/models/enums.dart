enum HomeRole {
  owner('OWNER'),
  admin('ADMIN'),
  editor('EDITOR'),
  viewer('VIEWER');

  const HomeRole(this.dbValue);
  final String dbValue;

  static HomeRole fromDb(String value) => HomeRole.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => HomeRole.viewer,
      );

  bool get canEditInventory =>
      this == HomeRole.owner || this == HomeRole.admin || this == HomeRole.editor;

  bool get canManageMembers =>
      this == HomeRole.owner || this == HomeRole.admin;

  bool get isOwner => this == HomeRole.owner;

  String get label => switch (this) {
        HomeRole.owner => 'Owner',
        HomeRole.admin => 'Admin',
        HomeRole.editor => 'Editor',
        HomeRole.viewer => 'Viewer',
      };
}

enum MembershipStatus {
  pending('PENDING'),
  active('ACTIVE'),
  removed('REMOVED'),
  left('LEFT');

  const MembershipStatus(this.dbValue);
  final String dbValue;

  static MembershipStatus fromDb(String value) =>
      MembershipStatus.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => MembershipStatus.pending,
      );
}

enum InventoryNodeKind {
  furniture('FURNITURE'),
  storageLocation('STORAGE_LOCATION'),
  item('ITEM');

  const InventoryNodeKind(this.dbValue);
  final String dbValue;

  static InventoryNodeKind fromDb(String value) =>
      InventoryNodeKind.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => InventoryNodeKind.item,
      );

  String get label => switch (this) {
        InventoryNodeKind.furniture => 'Furniture',
        InventoryNodeKind.storageLocation => 'Storage',
        InventoryNodeKind.item => 'Item',
      };
}

enum ItemCategory {
  edible('EDIBLE'),
  consumable('CONSUMABLE'),
  clothing('CLOTHING'),
  bagLuggage('BAG_LUGGAGE'),
  electronics('ELECTRONICS'),
  misc('MISC');

  const ItemCategory(this.dbValue);
  final String dbValue;

  static ItemCategory? fromDb(String? value) {
    if (value == null) return null;
    return ItemCategory.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => ItemCategory.misc,
    );
  }

  String get label => switch (this) {
        ItemCategory.edible => 'Edible',
        ItemCategory.consumable => 'Consumable',
        ItemCategory.clothing => 'Clothing',
        ItemCategory.bagLuggage => 'Bag / Luggage',
        ItemCategory.electronics => 'Electronics',
        ItemCategory.misc => 'Misc',
      };
}
