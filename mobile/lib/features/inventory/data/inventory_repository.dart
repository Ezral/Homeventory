import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/enums.dart';
import '../../../shared/models/inventory_node.dart';

class InventoryRepository {
  InventoryRepository(this._client);

  final SupabaseClient _client;

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
        .isFilter('archived_at', null);

    query = parentNodeId == null
        ? query.isFilter('parent_node_id', null)
        : query.eq('parent_node_id', parentNodeId);

    final rows = await query.order('name');
    return (rows as List)
        .map(
          (r) => InventoryNode.fromJson(Map<String, dynamic>.from(r as Map)),
        )
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

    final rows = await _client
        .from('inventory_nodes')
        .select()
        .eq('home_id', homeId)
        .isFilter('archived_at', null)
        .ilike('name', '%$trimmed%')
        .order('name')
        .limit(limit);

    return (rows as List)
        .map(
          (r) => InventoryNode.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
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
    ItemCategory? itemCategory,
    double? quantity,
    String? quantityUnit,
  }) async {
    final inserted = await _client
        .from('inventory_nodes')
        .insert({
          'home_id': homeId,
          'room_id': roomId,
          'parent_node_id': parentNodeId,
          'node_kind': nodeKind.dbValue,
          'name': name.trim(),
          'description':
              description?.trim().isEmpty == true ? null : description?.trim(),
          'is_container': isContainer || isMobileContainer,
          'is_mobile_container': isMobileContainer,
          'item_category': itemCategory?.dbValue,
          'quantity': quantity,
          'quantity_unit': quantityUnit,
          'created_by_user_id': _userId,
        })
        .select()
        .single();

    return InventoryNode.fromJson(Map<String, dynamic>.from(inserted));
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

  Future<void> archiveNode(String nodeId) async {
    await _client.from('inventory_nodes').update({
      'archived_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', nodeId);
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
}
