import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/enums.dart';
import '../../../shared/models/inventory_node.dart';

class Trip {
  const Trip({
    required this.id,
    required this.homeId,
    required this.name,
    this.notes,
    required this.status,
    this.startsOn,
    this.endsOn,
    required this.createdByUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String homeId;
  final String name;
  final String? notes;
  final TripStatus status;
  final DateTime? startsOn;
  final DateTime? endsOn;
  final String createdByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String,
      homeId: json['home_id'] as String,
      name: json['name'] as String,
      notes: json['notes'] as String?,
      status: TripStatus.fromDb(json['status'] as String),
      startsOn: json['starts_on'] != null
          ? DateTime.tryParse(json['starts_on'] as String)
          : null,
      endsOn: json['ends_on'] != null
          ? DateTime.tryParse(json['ends_on'] as String)
          : null,
      createdByUserId: json['created_by_user_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class TripContainer {
  const TripContainer({
    required this.id,
    required this.homeId,
    required this.tripId,
    required this.inventoryNodeId,
    required this.createdAt,
    this.node,
  });

  final String id;
  final String homeId;
  final String tripId;
  final String inventoryNodeId;
  final DateTime createdAt;
  final InventoryNode? node;

  factory TripContainer.fromJson(
    Map<String, dynamic> json, {
    InventoryNode? node,
  }) {
    return TripContainer(
      id: json['id'] as String,
      homeId: json['home_id'] as String,
      tripId: json['trip_id'] as String,
      inventoryNodeId: json['inventory_node_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      node: node,
    );
  }
}

class TripItem {
  const TripItem({
    required this.id,
    required this.homeId,
    required this.tripId,
    required this.inventoryNodeId,
    required this.packedIntoNodeId,
    required this.originalRoomId,
    this.originalParentNodeId,
    required this.status,
    required this.packedAt,
    this.unpackedAt,
    required this.packedByUserId,
    this.node,
    this.packedIntoNode,
  });

  final String id;
  final String homeId;
  final String tripId;
  final String inventoryNodeId;
  final String packedIntoNodeId;
  final String originalRoomId;
  final String? originalParentNodeId;
  final TripItemStatus status;
  final DateTime packedAt;
  final DateTime? unpackedAt;
  final String packedByUserId;
  final InventoryNode? node;
  final InventoryNode? packedIntoNode;

  factory TripItem.fromJson(
    Map<String, dynamic> json, {
    InventoryNode? node,
    InventoryNode? packedIntoNode,
  }) {
    return TripItem(
      id: json['id'] as String,
      homeId: json['home_id'] as String,
      tripId: json['trip_id'] as String,
      inventoryNodeId: json['inventory_node_id'] as String,
      packedIntoNodeId: json['packed_into_node_id'] as String,
      originalRoomId: json['original_room_id'] as String,
      originalParentNodeId: json['original_parent_node_id'] as String?,
      status: TripItemStatus.fromDb(json['status'] as String),
      packedAt: DateTime.parse(json['packed_at'] as String),
      unpackedAt: json['unpacked_at'] != null
          ? DateTime.tryParse(json['unpacked_at'] as String)
          : null,
      packedByUserId: json['packed_by_user_id'] as String,
      node: node,
      packedIntoNode: packedIntoNode,
    );
  }
}

class TripsRepository {
  TripsRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not signed in');
    return id;
  }

  Future<List<Trip>> listTrips(String homeId) async {
    final rows = await _client
        .from('trips')
        .select()
        .eq('home_id', homeId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => Trip.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<Trip> createTrip({
    required String homeId,
    required String name,
    String? notes,
  }) async {
    final row = await _client
        .from('trips')
        .insert({
          'home_id': homeId,
          'name': name.trim(),
          'notes': _nullIfBlank(notes),
          'created_by_user_id': _userId,
        })
        .select()
        .single();

    return Trip.fromJson(Map<String, dynamic>.from(row));
  }

  Future<Trip> getTrip(String tripId) async {
    final row = await _client.from('trips').select().eq('id', tripId).single();
    return Trip.fromJson(Map<String, dynamic>.from(row));
  }

  Future<TripContainer> assignContainer({
    required String tripId,
    required String nodeId,
  }) async {
    final trip = await getTrip(tripId);
    final row = await _client
        .from('trip_containers')
        .insert({
          'home_id': trip.homeId,
          'trip_id': tripId,
          'inventory_node_id': nodeId,
        })
        .select()
        .single();

    return TripContainer.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<TripContainer>> listTripContainers(String tripId) async {
    final rows = await _client
        .from('trip_containers')
        .select()
        .eq('trip_id', tripId)
        .order('created_at');

    final containers = <TripContainer>[];
    for (final r in rows as List) {
      final map = Map<String, dynamic>.from(r as Map);
      InventoryNode? node;
      try {
        node = await _getNode(map['inventory_node_id'] as String);
      } catch (_) {}
      containers.add(TripContainer.fromJson(map, node: node));
    }
    return containers;
  }

  Future<List<TripItem>> listTripItems(String tripId) async {
    final rows = await _client
        .from('trip_items')
        .select()
        .eq('trip_id', tripId)
        .order('packed_at', ascending: false);

    final items = <TripItem>[];
    for (final r in rows as List) {
      final map = Map<String, dynamic>.from(r as Map);
      InventoryNode? node;
      InventoryNode? packedIntoNode;
      try {
        node = await _getNode(map['inventory_node_id'] as String);
      } catch (_) {}
      try {
        packedIntoNode = await _getNode(map['packed_into_node_id'] as String);
      } catch (_) {}
      items.add(
        TripItem.fromJson(map, node: node, packedIntoNode: packedIntoNode),
      );
    }
    return items;
  }

  Future<List<InventoryNode>> listMobileContainers(String homeId) async {
    final rows = await _client
        .from('inventory_nodes')
        .select()
        .eq('home_id', homeId)
        .eq('is_mobile_container', true)
        .eq('is_disposed', false)
        .isFilter('archived_at', null)
        .order('name');

    return (rows as List)
        .map((r) => InventoryNode.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<TripItem> packItem({
    required String tripId,
    required String nodeId,
    required String packedIntoNodeId,
  }) async {
    final row = await _client.rpc(
      'pack_item_into_container',
      params: {
        'p_trip_id': tripId,
        'p_node_id': nodeId,
        'p_packed_into_node_id': packedIntoNodeId,
      },
    );
    return TripItem.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<TripItem> unpackItem(String tripItemId) async {
    final row = await _client.rpc(
      'unpack_item',
      params: {'p_trip_item_id': tripItemId},
    );
    return TripItem.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<InventoryNode> _getNode(String nodeId) async {
    final row = await _client
        .from('inventory_nodes')
        .select()
        .eq('id', nodeId)
        .single();
    return InventoryNode.fromJson(Map<String, dynamic>.from(row));
  }

  String? _nullIfBlank(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
