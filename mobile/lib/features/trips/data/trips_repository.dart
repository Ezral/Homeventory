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
    this.luggageAllowanceKg,
    this.archivedAt,
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
  final double? luggageAllowanceKg;
  final DateTime? archivedAt;
  final String createdByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isArchived => archivedAt != null;

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
      luggageAllowanceKg: (json['luggage_allowance_kg'] as num?)?.toDouble(),
      archivedAt: json['archived_at'] != null
          ? DateTime.tryParse(json['archived_at'] as String)
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
    this.packedAt,
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
  final DateTime? packedAt;
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
      packedAt: json['packed_at'] != null
          ? DateTime.parse(json['packed_at'] as String)
          : null,
      unpackedAt: json['unpacked_at'] != null
          ? DateTime.tryParse(json['unpacked_at'] as String)
          : null,
      packedByUserId: json['packed_by_user_id'] as String,
      node: node,
      packedIntoNode: packedIntoNode,
    );
  }
}

class TripWeightSummary {
  const TripWeightSummary({
    required this.allowanceKg,
    required this.packedKg,
    required this.containersKg,
    required this.itemsKg,
    required this.missingWeightCount,
  });

  final double? allowanceKg;
  final double packedKg;
  final double containersKg;
  final double itemsKg;
  final int missingWeightCount;

  double? get availableKg =>
      allowanceKg == null ? null : allowanceKg! - packedKg;

  bool get isOverAllowance =>
      allowanceKg != null && packedKg > allowanceKg!;
}

/// Convert a node weight to kilograms; null if weight is unset.
double? inventoryWeightKg(InventoryNode? node) {
  if (node?.weight == null) return null;
  final w = node!.weight!;
  final unit = (node.weightUnit ?? 'kg').trim().toLowerCase();
  return switch (unit) {
    'kg' || 'kilogram' || 'kilograms' => w,
    'g' || 'gram' || 'grams' => w / 1000,
    'lb' || 'lbs' || 'pound' || 'pounds' => w * 0.45359237,
    'oz' || 'ounce' || 'ounces' => w * 0.028349523125,
    _ => w,
  };
}

TripWeightSummary buildTripWeightSummary({
  required Trip trip,
  required List<TripContainer> containers,
  required List<TripItem> items,
}) {
  var containersKg = 0.0;
  var missing = 0;
  for (final container in containers) {
    final kg = inventoryWeightKg(container.node);
    if (kg == null) {
      if (container.node != null) missing += 1;
    } else {
      containersKg += kg;
    }
  }

  var itemsKg = 0.0;
  for (final item in items) {
    if (item.status != TripItemStatus.packed) continue;
    final kg = inventoryWeightKg(item.node);
    if (kg == null) {
      missing += 1;
    } else {
      itemsKg += kg;
    }
  }

  return TripWeightSummary(
    allowanceKg: trip.luggageAllowanceKg,
    packedKg: containersKg + itemsKg,
    containersKg: containersKg,
    itemsKg: itemsKg,
    missingWeightCount: missing,
  );
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
        .isFilter('archived_at', null)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => Trip.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<Trip> createTrip({
    required String homeId,
    required String name,
    String? notes,
    double? luggageAllowanceKg,
  }) async {
    final row = await _client
        .from('trips')
        .insert({
          'home_id': homeId,
          'name': name.trim(),
          'notes': _nullIfBlank(notes),
          'luggage_allowance_kg': luggageAllowanceKg,
          'created_by_user_id': _userId,
        })
        .select()
        .single();

    return Trip.fromJson(Map<String, dynamic>.from(row));
  }

  Future<Trip> updateTrip({
    required String tripId,
    required String name,
    String? notes,
    TripStatus? status,
    double? luggageAllowanceKg,
    DateTime? startsOn,
    DateTime? endsOn,
  }) async {
    final row = await _client
        .from('trips')
        .update({
          'name': name.trim(),
          'notes': _nullIfBlank(notes),
          if (status != null) 'status': status.dbValue,
          'luggage_allowance_kg': luggageAllowanceKg,
          'starts_on': startsOn?.toIso8601String().split('T').first,
          'ends_on': endsOn?.toIso8601String().split('T').first,
        })
        .eq('id', tripId)
        .select()
        .single();
    return Trip.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> archiveTrip(String tripId) async {
    await _client
        .from('trips')
        .update({
          'archived_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', tripId);
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

  Future<int> addItemsToPackingPlan({
    required String tripId,
    required List<String> nodeIds,
    required String packedIntoNodeId,
  }) async {
    final count = await _client.rpc(
      'add_items_to_packing_plan',
      params: {
        'p_trip_id': tripId,
        'p_node_ids': nodeIds,
        'p_packed_into_node_id': packedIntoNodeId,
      },
    );
    return (count as num?)?.toInt() ?? 0;
  }

  Future<void> removeFromPackingPlan(String tripItemId) async {
    await _client.rpc(
      'remove_from_packing_plan',
      params: {'p_trip_item_id': tripItemId},
    );
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
