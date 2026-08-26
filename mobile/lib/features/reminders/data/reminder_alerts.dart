import '../../../shared/models/reminder.dart';
import '../../inventory/data/inventory_repository.dart';
import 'notification_scheduler.dart';

/// Resolves item/room photo URLs so Android can bake them into the
/// notification card at schedule time.
Future<List<ScheduledReminderAlert>> buildScheduledReminderAlerts(
  List<Reminder> reminders,
  InventoryRepository inventory,
) async {
  if (reminders.isEmpty) return const [];
  final homeId = reminders.first.homeId;
  final nodeIds = reminders
      .map((r) => r.inventoryNodeId)
      .whereType<String>()
      .toSet()
      .toList();
  final roomIds = reminders
      .where((r) => r.inventoryNodeId == null)
      .map((r) => r.roomId)
      .whereType<String>()
      .toSet()
      .toList();
  Map<String, String> nodeUrls = const {};
  Map<String, String> roomUrls = const {};
  try {
    nodeUrls = await inventory.latestImageUrls(
      homeId: homeId,
      entityType: 'INVENTORY_NODE',
      entityIds: nodeIds,
    );
  } catch (_) {}
  try {
    roomUrls = await inventory.latestImageUrls(
      homeId: homeId,
      entityType: 'ROOM',
      entityIds: roomIds,
    );
  } catch (_) {}

  return [
    for (final reminder in reminders)
      ScheduledReminderAlert.fromReminder(
        reminder,
        imageUrl: reminder.inventoryNodeId != null
            ? nodeUrls[reminder.inventoryNodeId]
            : roomUrls[reminder.roomId],
      ),
  ];
}
