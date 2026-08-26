import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../shared/models/enums.dart';

const demoStudioCatalogAsset = 'assets/demo_studio/catalog.json';

class DemoStudioCatalog {
  const DemoStudioCatalog({
    required this.home,
    required this.photos,
    required this.rooms,
    required this.expectedItemCount,
    required this.expectedValue,
  });

  final DemoStudioHome home;
  final Map<String, String> photos;
  final List<DemoStudioRoom> rooms;
  final int expectedItemCount;
  final double expectedValue;

  static Future<DemoStudioCatalog> load([AssetBundle? bundle]) async {
    final raw = await (bundle ?? rootBundle).loadString(demoStudioCatalogAsset);
    return DemoStudioCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  factory DemoStudioCatalog.fromJson(Map<String, dynamic> json) {
    return DemoStudioCatalog(
      home: DemoStudioHome.fromJson(
        Map<String, dynamic>.from(json['home'] as Map),
      ),
      photos: {
        for (final e in (json['photos'] as Map).entries)
          e.key as String: e.value as String,
      },
      rooms: [
        for (final room in json['rooms'] as List)
          DemoStudioRoom.fromJson(Map<String, dynamic>.from(room as Map)),
      ],
      expectedItemCount: (json['expectedItemCount'] as num).toInt(),
      expectedValue: (json['expectedValue'] as num).toDouble(),
    );
  }

  String photoAsset(String? key) {
    if (key == null) return photos.values.first;
    return photos[key] ?? photos.values.first;
  }

  Iterable<DemoStudioNode> get inventoryEntries sync* {
    for (final room in rooms) {
      yield* room.nodes.expand((n) => n.inventoryEntries);
    }
  }

  double get listedValue => inventoryEntries.fold<double>(
    0,
    (sum, n) => sum + (n.quantity ?? 1) * (n.price ?? 0),
  );
}

class DemoStudioHome {
  const DemoStudioHome({
    required this.name,
    this.description,
    this.addressText,
    required this.timezone,
    required this.defaultCurrency,
    this.photo,
    this.residingSince,
  });

  final String name;
  final String? description;
  final String? addressText;
  final String timezone;
  final String defaultCurrency;
  final String? photo;
  final DateTime? residingSince;

  factory DemoStudioHome.fromJson(Map<String, dynamic> json) {
    return DemoStudioHome(
      name: json['name'] as String,
      description: json['description'] as String?,
      addressText: json['addressText'] as String?,
      timezone: json['timezone'] as String,
      defaultCurrency: json['defaultCurrency'] as String,
      photo: json['photo'] as String?,
      residingSince: json['residingSince'] == null
          ? null
          : DateTime.tryParse(json['residingSince'] as String),
    );
  }
}

class DemoStudioRoom {
  const DemoStudioRoom({
    required this.name,
    this.description,
    this.photo,
    this.sortOrder = 0,
    this.nodes = const [],
  });

  final String name;
  final String? description;
  final String? photo;
  final int sortOrder;
  final List<DemoStudioNode> nodes;

  factory DemoStudioRoom.fromJson(Map<String, dynamic> json) {
    return DemoStudioRoom(
      name: json['name'] as String,
      description: json['description'] as String?,
      photo: json['photo'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      nodes: [
        for (final n in json['nodes'] as List? ?? const [])
          DemoStudioNode.fromJson(Map<String, dynamic>.from(n as Map)),
      ],
    );
  }
}

class DemoStudioNode {
  const DemoStudioNode({
    required this.name,
    required this.kind,
    this.category,
    this.container = false,
    this.quantity,
    this.price,
    this.currency,
    this.purchased,
    this.photo,
    this.description,
    this.children = const [],
  });

  final String name;
  final InventoryNodeKind kind;
  final ItemCategory? category;
  final bool container;
  final double? quantity;
  final double? price;
  final String? currency;
  final DateTime? purchased;
  final String? photo;
  final String? description;
  final List<DemoStudioNode> children;

  bool get isInventoryEntry => kind != InventoryNodeKind.storageLocation;

  Iterable<DemoStudioNode> get inventoryEntries sync* {
    if (isInventoryEntry) yield this;
    for (final child in children) {
      yield* child.inventoryEntries;
    }
  }

  factory DemoStudioNode.fromJson(Map<String, dynamic> json) {
    final kind = InventoryNodeKind.fromDb(json['kind'] as String);
    return DemoStudioNode(
      name: json['name'] as String,
      kind: kind,
      category:
          ItemCategory.fromDb(json['category'] as String?) ??
          (kind == InventoryNodeKind.item ? ItemCategory.misc : null),
      container: json['container'] as bool? ?? false,
      quantity: (json['quantity'] as num?)?.toDouble(),
      price: (json['price'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      purchased: json['purchased'] == null
          ? null
          : DateTime.tryParse(json['purchased'] as String),
      photo: json['photo'] as String?,
      description: json['description'] as String?,
      children: [
        for (final n in json['children'] as List? ?? const [])
          DemoStudioNode.fromJson(Map<String, dynamic>.from(n as Map)),
      ],
    );
  }
}
