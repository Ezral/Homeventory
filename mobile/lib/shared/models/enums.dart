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
      this == HomeRole.owner ||
      this == HomeRole.admin ||
      this == HomeRole.editor;

  bool get canManageMembers => this == HomeRole.owner || this == HomeRole.admin;

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

enum InventoryTransactionType {
  initialStock('INITIAL_STOCK'),
  use('USE'),
  restock('RESTOCK'),
  adjustment('ADJUSTMENT'),
  dispose('DISPOSE'),
  transferRefill('TRANSFER_REFILL'),
  move('MOVE');

  const InventoryTransactionType(this.dbValue);
  final String dbValue;

  static InventoryTransactionType fromDb(String value) =>
      InventoryTransactionType.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => InventoryTransactionType.adjustment,
      );

  String get label => switch (this) {
    InventoryTransactionType.initialStock => 'Initial stock',
    InventoryTransactionType.use => 'Use',
    InventoryTransactionType.restock => 'Restock',
    InventoryTransactionType.adjustment => 'Adjustment',
    InventoryTransactionType.dispose => 'Dispose',
    InventoryTransactionType.transferRefill => 'Transfer refill',
    InventoryTransactionType.move => 'Move',
  };
}

enum DispenserMode {
  single('SINGLE'),
  multi('MULTI');

  const DispenserMode(this.dbValue);
  final String dbValue;

  static DispenserMode fromDb(String? value) => DispenserMode.values.firstWhere(
    (e) => e.dbValue == value,
    orElse: () => DispenserMode.single,
  );

  String get label => switch (this) {
    DispenserMode.single => 'Single product',
    DispenserMode.multi => 'Multi (up to 3)',
  };

  int get maxSlots => switch (this) {
    DispenserMode.single => 1,
    DispenserMode.multi => 3,
  };
}

enum ConsumableForm {
  liquid('LIQUID'),
  gel('GEL'),
  cream('CREAM'),
  foam('FOAM'),
  powder('POWDER'),
  other('OTHER');

  const ConsumableForm(this.dbValue);
  final String dbValue;

  static ConsumableForm? fromDb(String? value) {
    if (value == null || value.isEmpty) return null;
    return ConsumableForm.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => ConsumableForm.other,
    );
  }

  String get label => switch (this) {
    ConsumableForm.liquid => 'Liquid',
    ConsumableForm.gel => 'Gel',
    ConsumableForm.cream => 'Cream',
    ConsumableForm.foam => 'Foam',
    ConsumableForm.powder => 'Powder',
    ConsumableForm.other => 'Other',
  };
}

enum TripStatus {
  planned('PLANNED'),
  active('ACTIVE'),
  completed('COMPLETED'),
  cancelled('CANCELLED');

  const TripStatus(this.dbValue);
  final String dbValue;

  static TripStatus fromDb(String value) => TripStatus.values.firstWhere(
    (e) => e.dbValue == value,
    orElse: () => TripStatus.planned,
  );

  String get label => switch (this) {
    TripStatus.planned => 'Planned',
    TripStatus.active => 'Active',
    TripStatus.completed => 'Completed',
    TripStatus.cancelled => 'Cancelled',
  };
}

enum TripItemStatus {
  packed('PACKED'),
  unpacked('UNPACKED');

  const TripItemStatus(this.dbValue);
  final String dbValue;

  static TripItemStatus fromDb(String value) =>
      TripItemStatus.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => TripItemStatus.packed,
      );

  String get label => switch (this) {
    TripItemStatus.packed => 'Packed',
    TripItemStatus.unpacked => 'Unpacked',
  };
}
