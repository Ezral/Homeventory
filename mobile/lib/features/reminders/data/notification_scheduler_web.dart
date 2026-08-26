import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'notification_scheduler.dart';

class WebReminderNotificationScheduler
    implements ReminderNotificationScheduler {
  @override
  bool get supportsBackgroundAlerts => false;

  @override
  String get platformNote =>
      'On the browser, manage the schedule here. Due items show in this list. '
      'Android can also notify in the background. Allow browser notifications '
      'to ping while this tab is open.';

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async {
    try {
      final result = await web.Notification.requestPermission().toDart;
      return result.toDart == 'granted';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> sync(List<ScheduledReminderAlert> alerts) async {
    final due = alerts.where((a) => !a.fireAt.isAfter(DateTime.now())).toList();
    if (due.isEmpty) return;
    var granted = false;
    try {
      granted = web.Notification.permission == 'granted';
    } catch (_) {
      return;
    }
    if (!granted) return;
    for (final alert in due.take(3)) {
      try {
        web.Notification(
          alert.title,
          web.NotificationOptions(body: alert.body),
        );
      } catch (_) {}
    }
  }

  @override
  Future<void> cancel(String reminderId) async {}
}

ReminderNotificationScheduler createReminderNotificationScheduler() {
  return WebReminderNotificationScheduler();
}
