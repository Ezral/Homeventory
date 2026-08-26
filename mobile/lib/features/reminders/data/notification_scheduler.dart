import '../../../shared/models/enums.dart';
import '../../../shared/models/reminder.dart';

class ScheduledReminderAlert {
  const ScheduledReminderAlert({
    required this.id,
    required this.title,
    required this.body,
    required this.fireAt,
    required this.repeat,
    this.intervalDays,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String body;
  final DateTime fireAt;
  final ReminderRepeat repeat;
  final int? intervalDays;
  final String? imageUrl;

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
      intervalDays: reminder.intervalDays,
      imageUrl: imageUrl,
    );
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
