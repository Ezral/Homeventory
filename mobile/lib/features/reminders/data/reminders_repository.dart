import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/enums.dart';
import '../../../shared/models/reminder.dart';

class RemindersRepository {
  RemindersRepository(this._client);

  final SupabaseClient _client;

  static const _select = '*, inventory_nodes(name, quantity, quantity_unit)';

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not signed in');
    return id;
  }

  Future<List<Reminder>> listReminders(String homeId) async {
    final rows = await _client
        .from('reminders')
        .select(_select)
        .eq('home_id', homeId)
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
    int leadDays = 2,
    bool enabled = true,
  }) async {
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
    int? leadDays,
    bool? enabled,
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
    if (inventoryNodeId != null) payload['inventory_node_id'] = inventoryNodeId;
    if (leadDays != null) payload['lead_days'] = leadDays;
    if (enabled != null) payload['enabled'] = enabled;

    final row = await _client
        .from('reminders')
        .update(payload)
        .eq('id', reminderId)
        .select(_select)
        .single();
    return Reminder.fromJson(Map<String, dynamic>.from(row));
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
