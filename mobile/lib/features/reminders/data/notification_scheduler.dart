import '../../../shared/models/enums.dart';
import '../../../shared/models/reminder.dart';
import '../../../shared/utils/reminder_schedule.dart';

class ScheduledReminderAlert {
  const ScheduledReminderAlert({
    required this.id,
    required this.title,
    required this.body,
    required this.fireAt,
    required this.repeat,
    required this.fireMinute,
    this.intervalDays,
    this.targetLabel,
    this.imageUrl,
    this.imagePath,
    this.details = '',
    this.itemOrRoomName,
    this.itemOrRoomId,
    this.imageContentDescription,
    this.recurrence,
    this.route = '/',
    this.canSnooze = true,
    this.canMarkDone = true,
  });

  final String id;
  final String title;
  final String body;
  final DateTime fireAt;
  final ReminderRepeat repeat;
  final int fireMinute;
  final int? intervalDays;
  final String? targetLabel;
  final String? imageUrl;
  final String? imagePath;
  final String details;
  final String? itemOrRoomName;
  final String? itemOrRoomId;
  final String? imageContentDescription;
  final String? recurrence;
  final String route;
  final bool canSnooze;
  final bool canMarkDone;

  factory ScheduledReminderAlert.fromReminder(
    Reminder reminder, {
    String? imageUrl,
  }) {
    final details = reminder.locationDetails;
    return ScheduledReminderAlert(
      id: reminder.id,
      title: reminder.title,
      body: reminder.body?.trim().isNotEmpty == true
          ? reminder.body!.trim()
          : reminder.kind == ReminderKind.usageRefill
          ? 'Time to refill ${reminder.nodeName ?? reminder.title}'
          : reminder.repeatSummary,
      fireAt: reminder.nextFireAt,
      repeat: reminder.repeat,
      fireMinute: reminder.fireMinute,
      intervalDays: reminder.intervalDays,
      targetLabel: reminder.targetName,
      imageUrl: imageUrl,
      details: details.isNotEmpty ? details : (reminder.body?.trim() ?? ''),
      itemOrRoomName: reminder.targetName,
      itemOrRoomId: reminder.inventoryNodeId ?? reminder.roomId,
      imageContentDescription: reminder.targetName,
      recurrence: reminder.recurrenceDescription,
      route: reminder.targetRoute ?? '/homes/${reminder.homeId}/schedule',
    );
  }

  ScheduledReminderAlert copyWith({String? imagePath, String? imageUrl}) {
    return ScheduledReminderAlert(
      id: id,
      title: title,
      body: body,
      fireAt: fireAt,
      repeat: repeat,
      fireMinute: fireMinute,
      intervalDays: intervalDays,
      targetLabel: targetLabel,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      details: details,
      itemOrRoomName: itemOrRoomName,
      itemOrRoomId: itemOrRoomId,
      imageContentDescription: imageContentDescription,
      recurrence: recurrence,
      route: route,
      canSnooze: canSnooze,
      canMarkDone: canMarkDone,
    );
  }

  /// Payload for the Android custom-layout scheduler.
  Map<String, dynamic> toNativePayload({required DateTime now}) {
    final due = !fireAt.isAfter(now);
    final once = repeat == ReminderRepeat.once;
    int? scheduleAtMillis;
    if (!once || fireAt.isAfter(now)) {
      final next = due
          ? nextFireAt(
              from: now,
              repeat: repeat,
              fireMinute: fireMinute,
              intervalDays: intervalDays,
              firstAt: fireAt,
            )
          : fireAt;
      scheduleAtMillis = next.toLocal().millisecondsSinceEpoch;
    }
    return {
      'id': notificationIdFor(id),
      'reminderId': id,
      'title': title,
      'body': body,
      'details': details,
      'targetLabel': targetLabel,
      'itemOrRoomName': itemOrRoomName,
      'itemOrRoomId': itemOrRoomId,
      'imagePath': imagePath,
      'imageContentDescription': imageContentDescription,
      'recurrence': recurrence,
      'route': route,
      'repeat': repeat.dbValue,
      'intervalDays': intervalDays ?? 1,
      'showNow': due,
      'scheduleAtMillis': scheduleAtMillis,
      'displayAtMillis': fireAt.toLocal().millisecondsSinceEpoch,
      'canSnooze': canSnooze,
      'canMarkDone': canMarkDone,
    };
  }
}

abstract class ReminderNotificationScheduler {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<void> sync(List<ScheduledReminderAlert> alerts);
  Future<void> cancel(String reminderId);
  bool get supportsBackgroundAlerts;
  String get platformNote;

  /// Debug-only sample notification. No-op on web/stub and in release.
  Future<void> previewSample() async {}

  Future<Map<String, dynamic>?> peekPendingAction() async => null;

  Future<void> consumePendingAction() async {}

  void setActionWakeHandler(void Function()? handler) {}
}

int notificationIdFor(String reminderId) => reminderId.hashCode & 0x7fffffff;
