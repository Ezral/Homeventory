import '../../../shared/models/reminder.dart';
import 'notification_scheduler.dart';

/// Resolves the latest item or room photo for each enabled reminder.
///
/// Prefers the linked item's photo, then the linked room, then the item's
/// parent room so a schedule always has a thumbnail when one exists.
Future<List<({Reminder reminder, String? imageUrl})>> reminderImageUrls({
  required List<Reminder> reminders,
  required Future<Map<String, String>> Function({
    required String homeId,
    required String entityType,
    required List<String> entityIds,
  })
  latestImageUrls,
}) async {
  if (reminders.isEmpty) return const [];

  final byHome = <String, List<Reminder>>{};
  for (final reminder in reminders) {
    byHome.putIfAbsent(reminder.homeId, () => []).add(reminder);
  }

  final urls = <String, String>{};
  for (final entry in byHome.entries) {
    final homeId = entry.key;
    final list = entry.value;
    final nodeIds = list
        .map((r) => r.inventoryNodeId)
        .whereType<String>()
        .toList();
    final roomIds = <String>{
      ...list.map((r) => r.roomId).whereType<String>(),
      ...list.map((r) => r.nodeRoomId).whereType<String>(),
    }.toList();

    final nodeUrls = await latestImageUrls(
      homeId: homeId,
      entityType: 'INVENTORY_NODE',
      entityIds: nodeIds,
    );
    final roomUrls = await latestImageUrls(
      homeId: homeId,
      entityType: 'ROOM',
      entityIds: roomIds,
    );

    for (final reminder in list) {
      final url =
          (reminder.inventoryNodeId != null
              ? nodeUrls[reminder.inventoryNodeId]
              : null) ??
          (reminder.roomId != null ? roomUrls[reminder.roomId] : null) ??
          (reminder.nodeRoomId != null ? roomUrls[reminder.nodeRoomId] : null);
      if (url != null) {
        urls[reminder.id] = url;
      }
    }
  }

  return [
    for (final reminder in reminders)
      (reminder: reminder, imageUrl: urls[reminder.id]),
  ];
}

Future<List<ScheduledReminderAlert>> scheduledAlertsWithImages({
  required List<Reminder> reminders,
  required Future<Map<String, String>> Function({
    required String homeId,
    required String entityType,
    required List<String> entityIds,
  })
  latestImageUrls,
}) async {
  final enabled = reminders.where((r) => r.enabled).toList();
  final pairs = await reminderImageUrls(
    reminders: enabled,
    latestImageUrls: latestImageUrls,
  );
  return [
    for (final pair in pairs)
      ScheduledReminderAlert.fromReminder(
        pair.reminder,
        imageUrl: pair.imageUrl,
      ),
  ];
}
