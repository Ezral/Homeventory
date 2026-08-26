import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../shared/models/enums.dart';
import 'notification_scheduler.dart';
import 'notification_scheduler_stub.dart';

class AndroidReminderNotificationScheduler
    implements ReminderNotificationScheduler {
  AndroidReminderNotificationScheduler()
    : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'homeventory_reminders',
    'Reminders',
    channelDescription: 'Cleanup alarms and refill reminders',
    importance: Importance.high,
    priority: Priority.high,
  );

  @override
  bool get supportsBackgroundAlerts => true;

  @override
  String get platformNote =>
      'Android will notify at the scheduled time, including when the app is in the background.';

  @override
  Future<void> initialize() async {
    if (_ready) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(
        const InitializationSettings(android: androidInit),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    if (!_ready) return false;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? false;
  }

  @override
  Future<void> sync(List<ScheduledReminderAlert> alerts) async {
    await initialize();
    if (!_ready) return;
    await _plugin.cancelAll();
    final now = DateTime.now();
    for (final alert in alerts) {
      if (alert.fireAt.isBefore(now.subtract(const Duration(minutes: 1))) &&
          alert.repeat == ReminderRepeat.once) {
        continue;
      }
      try {
        await _schedule(alert);
      } catch (_) {}
    }
  }

  @override
  Future<void> cancel(String reminderId) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(notificationIdFor(reminderId));
    } catch (_) {}
  }

  Future<void> _schedule(ScheduledReminderAlert alert) async {
    var when = tz.TZDateTime.from(alert.fireAt.toLocal(), tz.local);
    final now = tz.TZDateTime.now(tz.local);
    if (!when.isAfter(now)) {
      if (alert.repeat == ReminderRepeat.once) return;
      when = when.add(const Duration(days: 1));
      while (!when.isAfter(now)) {
        when = when.add(const Duration(days: 1));
      }
    }

    DateTimeComponents? match;
    switch (alert.repeat) {
      case ReminderRepeat.daily:
        match = DateTimeComponents.time;
      case ReminderRepeat.weekly:
        match = DateTimeComponents.dayOfWeekAndTime;
      case ReminderRepeat.monthly:
        match = DateTimeComponents.dayOfMonthAndTime;
      case ReminderRepeat.once:
      case ReminderRepeat.customDays:
        match = null;
    }

    await _plugin.zonedSchedule(
      notificationIdFor(alert.id),
      alert.title,
      alert.body,
      when,
      const NotificationDetails(android: _channel),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: match,
    );
  }
}

ReminderNotificationScheduler createReminderNotificationScheduler() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return AndroidReminderNotificationScheduler();
  }
  return StubReminderNotificationScheduler();
}
