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

  factory ScheduledReminderAlert.fromReminder(
    Reminder reminder, {
    String? imageUrl,
  }) {
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
      'title': title,
      'body': body,
      'targetLabel': targetLabel,
      'imagePath': imagePath,
      'repeat': repeat.dbValue,
      'intervalDays': intervalDays ?? 1,
      'showNow': due,
      'scheduleAtMillis': scheduleAtMillis,
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
}

int notificationIdFor(String reminderId) => reminderId.hashCode & 0x7fffffff;
