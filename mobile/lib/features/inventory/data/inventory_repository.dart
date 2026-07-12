import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/models/enums.dart';
import '../../../shared/models/inventory_node.dart';

class ItemBarcode {
  const ItemBarcode({
    required this.id,
    required this.homeId,
    required this.inventoryNodeId,
    required this.barcodeValue,
    this.barcodeFormat,
    this.isPrimary = false,
  });

  final String id;
  final String homeId;
  final String inventoryNodeId;
  final String barcodeValue;
  final String? barcodeFormat;
  final bool isPrimary;

  factory ItemBarcode.fromJson(Map<String, dynamic> json) {
    return ItemBarcode(
      id: json['id'] as String,
      homeId: json['home_id'] as String,
      inventoryNodeId: json['inventory_node_id'] as String,
      barcodeValue: json['barcode_value'] as String,
      barcodeFormat: json['barcode_format'] as String?,
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }
}

class EntityImage {
  const EntityImage({
    required this.id,
    required this.homeId,
    required this.entityType,
    required this.entityId,
    required this.storagePath,
    this.mimeType,
    this.signedUrl,
  });

  final String id;
  final String homeId;
  final String entityType;
  final String entityId;
  final String storagePath;
  final String? mimeType;
  final String? signedUrl;

  factory EntityImage.fromJson(Map<String, dynamic> json, {String? signedUrl}) {
    return EntityImage(
      id: json['id'] as String,
      homeId: json['home_id'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      storagePath: json['storage_path'] as String,
      mimeType: json['mime_type'] as String?,
      signedUrl: signedUrl,
    );
  }
}

class InventoryTransaction {
  const InventoryTransaction({
    required this.id,
    required this.homeId,
    required this.inventoryNodeId,
    this.relatedNodeId,
    required this.transactionType,
    this.quantityDelta,
    this.quantityBefore,
    this.quantityAfter,
    this.quantityUnit,
    this.reason,
    required this.createdByUserId,
    required this.createdAt,
  });

  final String id;
  final String homeId;
  final String inventoryNodeId;
  final String? relatedNodeId;
  final InventoryTransactionType transactionType;
  final double? quantityDelta;
  final double? quantityBefore;
  final double? quantityAfter;
  final String? quantityUnit;
  final String? reason;
  final String createdByUserId;
  final DateTime createdAt;

  factory InventoryTransaction.fromJson(Map<String, dynamic> json) {
    return InventoryTransaction(
      id: json['id'] as String,
      homeId: json['home_id'] as String,
      inventoryNodeId: json['inventory_node_id'] as String,
      relatedNodeId: json['related_node_id'] as String?,
      transactionType: InventoryTransactionType.fromDb(
        json['transaction_type'] as String,
      ),
      quantityDelta: (json['quantity_delta'] as num?)?.toDouble(),
      quantityBefore: (json['quantity_before'] as num?)?.toDouble(),
      quantityAfter: (json['quantity_after'] as num?)?.toDouble(),
      quantityUnit: json['quantity_unit'] as String?,
      reason: json['reason'] as String?,
      createdByUserId: json['created_by_user_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class InventoryRepository {
  InventoryRepository(this._client);

  final SupabaseClient _client;
  static const _uuid = Uuid();

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not signed in');
    return id;
  }

  Future<List<InventoryNode>> listChildren({
    required String homeId,
    required String roomId,
    String? parentNodeId,
  }) async {
    var query = _client
        .from('inventory_nodes')
        .select()
        .eq('home_id', homeId)
        .eq('room_id', roomId)
        .eq('is_disposed', false)
        .isFilter('archived_at', null);

    query = parentNodeId == null
        ? query.isFilter('parent_node_id', null)
        : query.eq('parent_node_id', parentNodeId);

    final rows = await query.order('name');
    return (rows as List)
        .map((r) => InventoryNode.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<InventoryNode> getNode(String nodeId) async {
    final row = await _client
        .from('inventory_nodes')
        .select()
        .eq('id', nodeId)
        .single();
    return InventoryNode.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<InventoryNode>> search({
    required String homeId,
    required String query,
    int limit = 40,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final byName = await _client
        .from('inventory_nodes')
        .select()
        .eq('home_id', homeId)
        .eq('is_disposed', false)
        .isFilter('archived_at', null)
        .ilike('name', '%$trimmed%')
        .order('name')
        .limit(limit);

    final barcodeRows = await _client
        .from('item_barcodes')
        .select('inventory_node_id')
        .eq('home_id', homeId)
        .ilike('barcode_value', '%$trimmed%')
        .limit(limit);

    final barcodeIds = (barcodeRows as List)
        .map((r) => (r as Map)['inventory_node_id'] as String)
        .toSet();

    final nodes = <String, InventoryNode>{};
    for (final r in byName as List) {
      final node = InventoryNode.fromJson(Map<String, dynamic>.from(r as Map));
      nodes[node.id] = node;
    }
    for (final id in barcodeIds) {
      if (nodes.containsKey(id)) continue;
      try {
        final node = await getNode(id);
        if (!node.isDisposed && !node.isArchived) nodes[id] = node;
      } catch (_) {}
    }
    return nodes.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<InventoryNode> createNode({
    required String homeId,
    required String roomId,
    String? parentNodeId,
    required InventoryNodeKind nodeKind,
    required String name,
    String? description,
    bool isContainer = false,
    bool isMobileContainer = false,
    bool isDispenser = false,
    double? capacity,
    ItemCategory? itemCategory,
    double? quantity,
    String? quantityUnit,
    double? minimumQuantity,
    double? purchasePrice,
    String? currency,
    DateTime? purchaseDate,
    DateTime? expirationDate,
    String? brand,
    double? weight,
    String? weightUnit,
  }) async {
    final inserted = await _client
        .from('inventory_nodes')
        .insert({
          'home_id': homeId,
          'room_id': roomId,
          'parent_node_id': parentNodeId,
          'node_kind': nodeKind.dbValue,
          'name': name.trim(),
          'description': _nullIfBlank(description),
          'is_container': isContainer || isMobileContainer,
          'is_mobile_container': isMobileContainer,
          'is_dispenser': isDispenser,
          'capacity': capacity,
          'item_category': itemCategory?.dbValue,
          'quantity': quantity,
          'quantity_unit': _nullIfBlank(quantityUnit),
          'minimum_quantity': minimumQuantity,
          'purchase_price': purchasePrice,
          'currency': _nullIfBlank(currency)?.toUpperCase(),
          'purchase_date': purchaseDate?.toIso8601String().split('T').first,
          'expiration_date': expirationDate?.toIso8601String().split('T').first,
          'brand': _nullIfBlank(brand),
          'weight': weight,
          'weight_unit': _nullIfBlank(weightUnit),
          'created_by_user_id': _userId,
        })
        .select()
        .single();

    return InventoryNode.fromJson(Map<String, dynamic>.from(inserted));
  }

  Future<InventoryNode> updateNode({
    required String nodeId,
    required String name,
    String? description,
    bool? isContainer,
    bool? isMobileContainer,
    bool? isDispenser,
    double? capacity,
    ItemCategory? itemCategory,
    double? quantity,
    String? quantityUnit,
    double? minimumQuantity,
    double? purchasePrice,
    String? currency,
    DateTime? purchaseDate,
    DateTime? expirationDate,
    String? brand,
    double? weight,
    String? weightUnit,
  }) async {
    final payload = <String, dynamic>{
      'name': name.trim(),
      'description': _nullIfBlank(description),
      'is_dispenser': isDispenser ?? false,
      'capacity': capacity,
      'item_category': itemCategory?.dbValue,
      'quantity': quantity,
      'quantity_unit': _nullIfBlank(quantityUnit),
      'minimum_quantity': minimumQuantity,
      'purchase_price': purchasePrice,
      'currency': _nullIfBlank(currency)?.toUpperCase(),
      'purchase_date': purchaseDate?.toIso8601String().split('T').first,
      'expiration_date': expirationDate?.toIso8601String().split('T').first,
      'brand': _nullIfBlank(brand),
      'weight': weight,
      'weight_unit': _nullIfBlank(weightUnit),
    };
    if (isContainer != null) payload['is_container'] = isContainer;
    if (isMobileContainer != null) {
      payload['is_mobile_container'] = isMobileContainer;
      if (isMobileContainer) payload['is_container'] = true;
    }

    final updated = await _client
        .from('inventory_nodes')
        .update(payload)
        .eq('id', nodeId)
        .select()
        .single();
    return InventoryNode.fromJson(Map<String, dynamic>.from(updated));
  }

  Future<void> moveNode({
    required String nodeId,
    required String destinationRoomId,
    String? destinationParentId,
  }) async {
    await _client.rpc(
      'move_inventory_node',
      params: {
        'p_node_id': nodeId,
        'p_destination_room_id': destinationRoomId,
        'p_destination_parent_node_id': destinationParentId,
      },
    );
  }

  Future<List<InventoryTransaction>> listTransactions(String nodeId) async {
    final rows = await _client
        .from('inventory_transactions')
        .select()
        .eq('inventory_node_id', nodeId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map(
          (r) => InventoryTransaction.fromJson(
            Map<String, dynamic>.from(r as Map),
          ),
        )
        .toList();
  }

  Future<InventoryTransaction> applyTransaction({
    required String nodeId,
    required InventoryTransactionType transactionType,
    double? quantityDelta,
    String? quantityUnit,
    String? reason,
    String? relatedNodeId,
  }) async {
    final row = await _client.rpc(
      'apply_inventory_transaction',
      params: {
        'p_node_id': nodeId,
        'p_transaction_type': transactionType.dbValue,
        'p_quantity_delta': quantityDelta,
        'p_quantity_unit': _nullIfBlank(quantityUnit),
        'p_reason': _nullIfBlank(reason),
        'p_related_node_id': relatedNodeId,
      },
    );
    return InventoryTransaction.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<void> archiveNode(String nodeId) async {
    await _client
        .from('inventory_nodes')
        .update({'archived_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', nodeId);
  }

  Future<List<InventoryNode>> breadcrumbPath(InventoryNode node) async {
    final path = <InventoryNode>[node];
    var currentParent = node.parentNodeId;
    while (currentParent != null) {
      final parent = await getNode(currentParent);
      path.insert(0, parent);
      currentParent = parent.parentNodeId;
    }
    return path;
  }

  Future<List<ItemBarcode>> listBarcodes(String nodeId) async {
    final rows = await _client
        .from('item_barcodes')
        .select()
        .eq('inventory_node_id', nodeId)
        .order('created_at');
    return (rows as List)
        .map((r) => ItemBarcode.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<ItemBarcode> addBarcode({
    required String homeId,
    required String nodeId,
    required String barcodeValue,
    String? barcodeFormat,
    bool isPrimary = false,
  }) async {
    final inserted = await _client
        .from('item_barcodes')
        .insert({
          'home_id': homeId,
          'inventory_node_id': nodeId,
          'barcode_value': barcodeValue.trim(),
          'barcode_format': barcodeFormat,
          'is_primary': isPrimary,
        })
        .select()
        .single();
    return ItemBarcode.fromJson(Map<String, dynamic>.from(inserted));
  }

  Future<void> removeBarcode(String barcodeId) async {
    await _client.from('item_barcodes').delete().eq('id', barcodeId);
  }

  Future<InventoryNode?> findByBarcode({
    required String homeId,
    required String barcodeValue,
  }) async {
    final row = await _client
        .from('item_barcodes')
        .select('inventory_node_id')
        .eq('home_id', homeId)
        .eq('barcode_value', barcodeValue.trim())
        .maybeSingle();
    if (row == null) return null;
    return getNode(row['inventory_node_id'] as String);
  }

  Future<List<EntityImage>> listImages({
    required String homeId,
    required String entityType,
    required String entityId,
  }) async {
    final rows = await _client
        .from('images')
        .select()
        .eq('home_id', homeId)
        .eq('entity_type', entityType)
        .eq('entity_id', entityId)
        .order('created_at', ascending: false);

    final images = <EntityImage>[];
    for (final r in rows as List) {
      final map = Map<String, dynamic>.from(r as Map);
      final path = map['storage_path'] as String;
      String? url;
      try {
        url = await _client.storage
            .from('home-images')
            .createSignedUrl(path, 3600);
      } catch (_) {}
      images.add(EntityImage.fromJson(map, signedUrl: url));
    }
    return images;
  }

  /// Latest signed image URL per entity id (for list thumbnails).
  Future<Map<String, String>> latestImageUrls({
    required String homeId,
    required String entityType,
    required List<String> entityIds,
  }) async {
    if (entityIds.isEmpty) return const {};
    final rows = await _client
        .from('images')
        .select('entity_id, storage_path, created_at')
        .eq('home_id', homeId)
        .eq('entity_type', entityType)
        .inFilter('entity_id', entityIds)
        .order('created_at', ascending: false);

    final paths = <String, String>{};
    for (final r in rows as List) {
      final map = Map<String, dynamic>.from(r as Map);
      final id = map['entity_id'] as String;
      if (paths.containsKey(id)) continue;
      paths[id] = map['storage_path'] as String;
    }

    final urls = <String, String>{};
    for (final entry in paths.entries) {
      try {
        urls[entry.key] = await _client.storage
            .from('home-images')
            .createSignedUrl(entry.value, 3600);
      } catch (_) {}
    }
    return urls;
  }

  Future<EntityImage> uploadEntityImage({
    required String homeId,
    required String entityType,
    required String entityId,
    required Uint8List bytes,
    required String mimeType,
    String extension = 'jpg',
  }) async {
    final filename = '${_uuid.v4()}.$extension';
    final path = '$homeId/$entityType/$entityId/$filename';
    await _client.storage
        .from('home-images')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
    final inserted = await _client
        .from('images')
        .insert({
          'home_id': homeId,
          'entity_type': entityType,
          'entity_id': entityId,
          'storage_path': path,
          'mime_type': mimeType,
          'file_size': bytes.length,
          'uploaded_by_user_id': _userId,
        })
        .select()
        .single();
    final url = await _client.storage
        .from('home-images')
        .createSignedUrl(path, 3600);
    return EntityImage.fromJson(
      Map<String, dynamic>.from(inserted),
      signedUrl: url,
    );
  }

  Future<EntityImage> uploadNodeImage({
    required String homeId,
    required String nodeId,
    required Uint8List bytes,
    required String mimeType,
    String extension = 'jpg',
  }) {
    return uploadEntityImage(
      homeId: homeId,
      entityType: 'INVENTORY_NODE',
      entityId: nodeId,
      bytes: bytes,
      mimeType: mimeType,
      extension: extension,
    );
  }

  Future<EntityImage> uploadRoomImage({
    required String homeId,
    required String roomId,
    required Uint8List bytes,
    required String mimeType,
    String extension = 'jpg',
  }) async {
    final image = await uploadEntityImage(
      homeId: homeId,
      entityType: 'ROOM',
      entityId: roomId,
      bytes: bytes,
      mimeType: mimeType,
      extension: extension,
    );
    await _client.from('rooms').update({'image_id': image.id}).eq('id', roomId);
    return image;
  }

  Future<void> deleteImage(EntityImage image) async {
    await _client.storage.from('home-images').remove([image.storagePath]);
    await _client.from('images').delete().eq('id', image.id);
  }

  String? _nullIfBlank(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
