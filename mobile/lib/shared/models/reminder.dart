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
    this.leadDays = 2,
    this.enabled = true,
    this.lastNotifiedAt,
    this.nodeName,
    this.nodeQuantity,
    this.nodeQuantityUnit,
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
  final int leadDays;
  final bool enabled;
  final DateTime? lastNotifiedAt;
  final String? nodeName;
  final double? nodeQuantity;
  final String? nodeQuantityUnit;

  int get fireHour => fireMinute ~/ 60;
  int get fireMinuteOfHour => fireMinute % 60;

  bool get isDue {
    if (!enabled) return false;
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
      leadDays: (json['lead_days'] as num?)?.toInt() ?? 2,
      enabled: json['enabled'] as bool? ?? true,
      lastNotifiedAt: json['last_notified_at'] != null
          ? DateTime.tryParse(json['last_notified_at'] as String)
          : null,
      nodeName: nodeMap?['name'] as String?,
      nodeQuantity: (nodeMap?['quantity'] as num?)?.toDouble(),
      nodeQuantityUnit: nodeMap?['quantity_unit'] as String?,
    );
  }
}
