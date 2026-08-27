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
  Future<void> previewSample() async {}

  @override
  Future<Map<String, dynamic>?> peekPendingAction() async => null;

  @override
  Future<void> consumePendingAction() async {}

  @override
  void setActionWakeHandler(void Function()? handler) {}

  @override
  bool get supportsBackgroundAlerts => false;

  @override
  String get platformNote =>
      'Schedules are saved for this home. Background alerts are not available here.';
}

ReminderNotificationScheduler createReminderNotificationScheduler() {
  return StubReminderNotificationScheduler();
}
