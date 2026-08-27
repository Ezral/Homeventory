import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/enums.dart';
import '../../../shared/models/reminder.dart';
import '../../../shared/utils/reminder_schedule.dart';

class RemindersRepository {
  RemindersRepository(this._client);

  final SupabaseClient _client;

  static const _select =
      '*, inventory_nodes(name, quantity, quantity_unit, room_id, is_container, rooms(name)), rooms(name)';

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not signed in');
    return id;
  }

  Future<List<Reminder>> listForNode({
    required String homeId,
    required String nodeId,
  }) async {
    final rows = await _client
        .from('reminders')
        .select(_select)
        .eq('home_id', homeId)
        .eq('inventory_node_id', nodeId)
        .filter('archived_at', 'is', null)
        .order('enabled', ascending: false)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Reminder.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<List<Reminder>> listForRoom({
    required String homeId,
    required String roomId,
  }) async {
    final rows = await _client
        .from('reminders')
        .select(_select)
        .eq('home_id', homeId)
        .eq('room_id', roomId)
        .filter('archived_at', 'is', null)
        .order('enabled', ascending: false)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Reminder.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<List<Reminder>> listReminders(String homeId) async {
    final rows = await _client
        .from('reminders')
        .select(_select)
        .eq('home_id', homeId)
        .filter('archived_at', 'is', null)
        .order('enabled', ascending: false)
        .order('next_fire_at');
    return (rows as List)
        .map((r) => Reminder.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<Reminder> getReminder(String reminderId) async {
    final row = await _client
        .from('reminders')
        .select(_select)
        .eq('id', reminderId)
        .single();
    return Reminder.fromJson(Map<String, dynamic>.from(row));
  }

  Future<Reminder> createReminder({
    required String homeId,
    required ReminderKind kind,
    required String title,
    String? body,
    required ReminderRepeat repeat,
    int? intervalDays,
    required int fireMinute,
    required DateTime nextFireAt,
    String? inventoryNodeId,
    String? roomId,
    int leadDays = 2,
    bool enabled = true,
  }) async {
    if ((inventoryNodeId == null) == (roomId == null)) {
      throw ArgumentError('Link the schedule to an item or a room.');
    }
    final row = await _client
        .from('reminders')
        .insert({
          'home_id': homeId,
          'created_by_user_id': _userId,
          'kind': kind.dbValue,
          'title': title.trim(),
          'body': _nullIfBlank(body),
          'repeat': repeat.dbValue,
          'interval_days': repeat == ReminderRepeat.customDays
              ? intervalDays
              : null,
          'fire_minute': fireMinute,
          'next_fire_at': nextFireAt.toUtc().toIso8601String(),
          'inventory_node_id': inventoryNodeId,
          'room_id': roomId,
          'lead_days': leadDays,
          'enabled': enabled,
        })
        .select(_select)
        .single();
    return Reminder.fromJson(Map<String, dynamic>.from(row));
  }

  Future<Reminder> updateReminder({
    required String reminderId,
    ReminderKind? kind,
    String? title,
    String? body,
    bool clearBody = false,
    ReminderRepeat? repeat,
    int? intervalDays,
    int? fireMinute,
    DateTime? nextFireAt,
    String? inventoryNodeId,
    String? roomId,
    bool setTarget = false,
    int? leadDays,
    bool? enabled,
    DateTime? archivedAt,
    DateTime? lastCompletedAt,
  }) async {
    final payload = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (kind != null) payload['kind'] = kind.dbValue;
    if (title != null) payload['title'] = title.trim();
    if (clearBody) {
      payload['body'] = null;
    } else if (body != null) {
      payload['body'] = _nullIfBlank(body);
    }
    if (repeat != null) payload['repeat'] = repeat.dbValue;
    if (repeat == ReminderRepeat.customDays || intervalDays != null) {
      payload['interval_days'] = intervalDays;
    }
    if (fireMinute != null) payload['fire_minute'] = fireMinute;
    if (nextFireAt != null) {
      payload['next_fire_at'] = nextFireAt.toUtc().toIso8601String();
    }
    if (setTarget) {
      payload['inventory_node_id'] = inventoryNodeId;
      payload['room_id'] = roomId;
    } else {
      if (inventoryNodeId != null) {
        payload['inventory_node_id'] = inventoryNodeId;
      }
      if (roomId != null) payload['room_id'] = roomId;
    }
    if (leadDays != null) payload['lead_days'] = leadDays;
    if (enabled != null) payload['enabled'] = enabled;
    if (archivedAt != null) {
      payload['archived_at'] = archivedAt.toUtc().toIso8601String();
    }
    if (lastCompletedAt != null) {
      payload['last_completed_at'] = lastCompletedAt.toUtc().toIso8601String();
    }

    final row = await _client
        .from('reminders')
        .update(payload)
        .eq('id', reminderId)
        .select(_select)
        .single();
    return Reminder.fromJson(Map<String, dynamic>.from(row));
  }

  Future<Reminder> completeReminder(Reminder reminder, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final result = completeSchedule(
      repeat: reminder.repeat,
      fireMinute: reminder.fireMinute,
      intervalDays: reminder.intervalDays,
      currentNext: reminder.nextFireAt,
      now: at,
    );
    if (result.archive) {
      return updateReminder(
        reminderId: reminder.id,
        enabled: false,
        archivedAt: at,
        lastCompletedAt: at,
      );
    }
    return updateReminder(
      reminderId: reminder.id,
      nextFireAt: result.nextFireAt,
      lastCompletedAt: at,
    );
  }

  Future<void> deleteReminder(String reminderId) async {
    await _client.from('reminders').delete().eq('id', reminderId);
  }

  String? _nullIfBlank(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
