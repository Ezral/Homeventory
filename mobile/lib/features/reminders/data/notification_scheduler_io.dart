import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../shared/models/enums.dart';
import 'notification_scheduler.dart';
import 'notification_scheduler_stub.dart';
import 'timezone_name.dart';

class AndroidReminderNotificationScheduler
    implements ReminderNotificationScheduler {
  AndroidReminderNotificationScheduler()
    : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;
  final Set<int> _shownDueIds = {};

  static const _channel = AndroidNotificationDetails(
    'homeventory_reminders',
    'Reminders',
    channelDescription: 'Cleanup alarms and refill reminders',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    icon: '@drawable/ic_stat_notify',
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
      final raw = await FlutterTimezone.getLocalTimezone();
      final name = resolveTimeZoneName(
        raw,
        knownNames: tz.timeZoneDatabase.locations.keys,
      );
      tz.setLocalLocation(tz.getLocation(name));
      const androidInit = AndroidInitializationSettings(
        '@drawable/ic_stat_notify',
      );
      await _plugin.initialize(
        const InitializationSettings(android: androidInit),
      );
      _ready = true;
    } catch (e, st) {
      debugPrint('Reminder notifications failed to initialize: $e\n$st');
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
    if (alerts.isNotEmpty) {
      await requestPermission();
    }
    await _plugin.cancelAll();
    _shownDueIds.clear();
    for (final alert in alerts) {
      try {
        await _schedule(alert);
      } catch (e, st) {
        debugPrint('Failed to schedule reminder ${alert.id}: $e\n$st');
      }
    }
  }

  @override
  Future<void> cancel(String reminderId) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(notificationIdFor(reminderId));
    } catch (e) {
      debugPrint('Failed to cancel reminder $reminderId: $e');
    }
  }

  Future<void> _schedule(ScheduledReminderAlert alert) async {
    final id = notificationIdFor(alert.id);
    final details = const NotificationDetails(android: _channel);
    var when = _zonedFrom(alert.fireAt);
    final now = tz.TZDateTime.now(tz.local);

    if (!when.isAfter(now)) {
      if (!_shownDueIds.contains(id)) {
        await _plugin.show(id, alert.title, alert.body, details);
        _shownDueIds.add(id);
      }
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
      id,
      alert.title,
      alert.body,
      when,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: match,
    );
  }

  tz.TZDateTime _zonedFrom(DateTime fireAt) {
    final local = fireAt.toLocal();
    return tz.TZDateTime(
      tz.local,
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
    );
  }
}

ReminderNotificationScheduler createReminderNotificationScheduler() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return AndroidReminderNotificationScheduler();
  }
  return StubReminderNotificationScheduler();
}
