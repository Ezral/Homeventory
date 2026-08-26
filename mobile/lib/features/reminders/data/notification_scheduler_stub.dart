import 'notification_scheduler.dart';

class StubReminderNotificationScheduler
    implements ReminderNotificationScheduler {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> sync(List<ScheduledReminderAlert> alerts) async {}

  @override
  Future<void> cancel(String reminderId) async {}

  @override
  bool get supportsBackgroundAlerts => false;

  @override
  String get platformNote =>
      'Reminders are saved for this home. Background alerts are not available here.';
}

ReminderNotificationScheduler createReminderNotificationScheduler() {
  return StubReminderNotificationScheduler();
}
