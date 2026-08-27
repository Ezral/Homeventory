import 'enums.dart';

class Reminder {
  const Reminder({
    required this.id,
    required this.homeId,
    required this.createdByUserId,
    required this.kind,
    required this.title,
    this.body,
    required this.repeat,
    this.intervalDays,
    required this.fireMinute,
    required this.nextFireAt,
    this.inventoryNodeId,
    this.roomId,
    this.leadDays = 2,
    this.enabled = true,
    this.lastNotifiedAt,
    this.archivedAt,
    this.lastCompletedAt,
    this.nodeName,
    this.nodeQuantity,
    this.nodeQuantityUnit,
    this.nodeRoomId,
    this.nodeIsContainer = false,
    this.roomName,
    this.nodeRoomName,
  });

  final String id;
  final String homeId;
  final String createdByUserId;
  final ReminderKind kind;
  final String title;
  final String? body;
  final ReminderRepeat repeat;
  final int? intervalDays;
  final int fireMinute;
  final DateTime nextFireAt;
  final String? inventoryNodeId;
  final String? roomId;
  final int leadDays;
  final bool enabled;
  final DateTime? lastNotifiedAt;
  final DateTime? archivedAt;
  final DateTime? lastCompletedAt;
  final String? nodeName;
  final double? nodeQuantity;
  final String? nodeQuantityUnit;
  final String? nodeRoomId;
  final bool nodeIsContainer;
  final String? roomName;
  final String? nodeRoomName;

  int get fireHour => fireMinute ~/ 60;
  int get fireMinuteOfHour => fireMinute % 60;

  bool get isArchived => archivedAt != null;

  bool get isRepeating => repeat != ReminderRepeat.once;

  String? get targetName => nodeName ?? roomName;

  /// Room + item line for notifications, e.g. "Bedroom · Air conditioner".
  String get locationDetails {
    final room = nodeRoomName ?? roomName;
    final item = nodeName;
    if (room != null &&
        room.isNotEmpty &&
        item != null &&
        item.isNotEmpty &&
        room != item) {
      return '$room · $item';
    }
    return item ?? room ?? '';
  }

  /// Recurrence line for expanded notifications. Null for one-off reminders.
  String? get recurrenceDescription {
    if (!isRepeating) return null;
    return 'Recurring ${repeatSummary.toLowerCase()}';
  }

  /// Browse path for the linked item or room.
  String? get targetRoute {
    final nodeId = inventoryNodeId;
    final nodeRoom = nodeRoomId;
    if (nodeId != null && nodeRoom != null) {
      final base = '/homes/$homeId/rooms/$nodeRoom/nodes/$nodeId';
      return nodeIsContainer ? base : '$base/details';
    }
    final linkedRoomId = roomId;
    if (linkedRoomId != null) {
      return '/homes/$homeId/rooms/$linkedRoomId';
    }
    return null;
  }

  /// Browse or detail path for the linked item, if room metadata is present.
  String? get itemRoute => inventoryNodeId == null ? null : targetRoute;

  bool get isDue {
    if (!enabled || isArchived) return false;
    return !nextFireAt.isAfter(DateTime.now());
  }

  String get repeatSummary {
    return switch (repeat) {
      ReminderRepeat.once => 'Once',
      ReminderRepeat.daily => 'Every day',
      ReminderRepeat.weekly => 'Every week',
      ReminderRepeat.monthly => 'Every month',
      ReminderRepeat.customDays =>
        'Every ${intervalDays ?? 1} day${(intervalDays ?? 1) == 1 ? '' : 's'}',
    };
  }

  factory Reminder.fromJson(Map<String, dynamic> json) {
    final node = json['inventory_nodes'];
    Map<String, dynamic>? nodeMap;
    if (node is Map) {
      nodeMap = Map<String, dynamic>.from(node);
    }
    final room = json['rooms'];
    Map<String, dynamic>? roomMap;
    if (room is Map) {
      roomMap = Map<String, dynamic>.from(room);
    }
    return Reminder(
      id: json['id'] as String,
      homeId: json['home_id'] as String,
      createdByUserId: json['created_by_user_id'] as String,
      kind: ReminderKind.fromDb(json['kind'] as String),
      title: json['title'] as String,
      body: json['body'] as String?,
      repeat: ReminderRepeat.fromDb(json['repeat'] as String),
      intervalDays: (json['interval_days'] as num?)?.toInt(),
      fireMinute: (json['fire_minute'] as num?)?.toInt() ?? 540,
      nextFireAt: DateTime.parse(json['next_fire_at'] as String),
      inventoryNodeId: json['inventory_node_id'] as String?,
      roomId: json['room_id'] as String?,
      leadDays: (json['lead_days'] as num?)?.toInt() ?? 2,
      enabled: json['enabled'] as bool? ?? true,
      lastNotifiedAt: json['last_notified_at'] != null
          ? DateTime.tryParse(json['last_notified_at'] as String)
          : null,
      archivedAt: json['archived_at'] != null
          ? DateTime.tryParse(json['archived_at'] as String)
          : null,
      lastCompletedAt: json['last_completed_at'] != null
          ? DateTime.tryParse(json['last_completed_at'] as String)
          : null,
      nodeName: nodeMap?['name'] as String?,
      nodeQuantity: (nodeMap?['quantity'] as num?)?.toDouble(),
      nodeQuantityUnit: nodeMap?['quantity_unit'] as String?,
      nodeRoomId: nodeMap?['room_id'] as String?,
      nodeIsContainer: nodeMap?['is_container'] as bool? ?? false,
      roomName: roomMap?['name'] as String?,
      nodeRoomName: _nestedRoomName(nodeMap),
    );
  }
}

String? _nestedRoomName(Map<String, dynamic>? nodeMap) {
  final nested = nodeMap?['rooms'];
  if (nested is Map) {
    return nested['name'] as String?;
  }
  return null;
}
