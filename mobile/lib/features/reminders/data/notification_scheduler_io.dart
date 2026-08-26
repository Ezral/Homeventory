import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../shared/models/enums.dart';
import '../../../shared/utils/notification_card.dart';
import 'notification_scheduler.dart';
import 'notification_scheduler_stub.dart';

class AndroidReminderNotificationScheduler
    implements ReminderNotificationScheduler {
  AndroidReminderNotificationScheduler()
    : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const _channelId = 'homeventory_reminders';
  static const _channelName = 'Reminders';
  static const _channelDescription = 'Cleanup alarms and refill reminders';

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

    final photo = await _downloadPhoto(alert.imageUrl);
    final card = await composeScheduleNotificationCard(
      photoBytes: photo,
      title: alert.title,
      body: alert.body,
    );

    await _plugin.zonedSchedule(
      notificationIdFor(alert.id),
      alert.title,
      alert.body,
      when,
      NotificationDetails(android: _androidDetails(card)),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: match,
    );
  }

  /// Expanded shade is the composed card (photo left third, text right).
  /// No `largeIcon`: Android would pin that thumbnail on the right.
  AndroidNotificationDetails _androidDetails(Uint8List card) {
    return AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigPictureStyleInformation(
        ByteArrayAndroidBitmap(card),
        hideExpandedLargeIcon: true,
        contentTitle: '',
        summaryText: '',
      ),
    );
  }

  Future<Uint8List?> _downloadPhoto(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }
      return response.bodyBytes;
    } catch (_) {
      return null;
    }
  }
}

ReminderNotificationScheduler createReminderNotificationScheduler() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return AndroidReminderNotificationScheduler();
  }
  return StubReminderNotificationScheduler();
}
