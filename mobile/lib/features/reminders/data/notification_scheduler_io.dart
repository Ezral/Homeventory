import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../shared/models/enums.dart';
import 'notification_scheduler.dart';
import 'notification_scheduler_stub.dart';
import 'reminder_image_cache.dart';
import 'timezone_name.dart';

const reminderNotificationChannel =
    'com.homeventory.homeventory/reminder_notifications';

class AndroidReminderNotificationScheduler
    implements ReminderNotificationScheduler {
  AndroidReminderNotificationScheduler({
    MethodChannel? channel,
    ReminderImageCache? imageCache,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _channel = channel ?? const MethodChannel(reminderNotificationChannel),
       _imageCache = imageCache ?? ReminderImageCache(),
       _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final MethodChannel _channel;
  final ReminderImageCache _imageCache;
  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;
  final Set<int> _shownDueIds = {};
  void Function()? _actionWakeHandler;

  static const _channelDetails = AndroidNotificationDetails(
    'homeventory_reminders',
    'Homeventory reminders',
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

    final withPhotos = <ScheduledReminderAlert>[];
    for (final alert in alerts) {
      final url = alert.imageUrl;
      if (url == null || url.isEmpty) {
        withPhotos.add(alert);
        continue;
      }
      final path = await _imageCache.cacheUrl(reminderId: alert.id, url: url);
      withPhotos.add(alert.copyWith(imagePath: path));
    }

    final now = DateTime.now();
    final payloads = [
      for (final alert in withPhotos) alert.toNativePayload(now: now),
    ];
    try {
      await _channel.invokeMethod<void>('sync', payloads);
    } catch (e, st) {
      debugPrint(
        'Native rich reminder notifications unavailable, using plugin: $e\n$st',
      );
      for (final alert in withPhotos) {
        try {
          await _scheduleWithPlugin(alert);
        } catch (err, stack) {
          debugPrint('Failed to schedule reminder ${alert.id}: $err\n$stack');
        }
      }
    }
  }

  @override
  Future<void> cancel(String reminderId) async {
    if (!_ready) return;
    final id = notificationIdFor(reminderId);
    try {
      await _channel.invokeMethod<void>('cancel', id);
    } catch (_) {}
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('Failed to cancel reminder $reminderId: $e');
    }
  }

  @override
  Future<void> previewSample() async {
    await initialize();
    if (!_ready) return;
    await requestPermission();
    try {
      await _channel.invokeMethod<void>('previewSample');
    } catch (e, st) {
      debugPrint('Failed to post reminder preview: $e\n$st');
    }
  }

  @override
  Future<Map<String, dynamic>?> peekPendingAction() async {
    try {
      final raw = await _channel.invokeMethod<dynamic>('peekPendingAction');
      if (raw is Map) {
        return raw.map(
          (key, value) => MapEntry('$key', value?.toString() ?? ''),
        );
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> consumePendingAction() async {
    try {
      await _channel.invokeMethod<void>('consumePendingAction');
    } catch (_) {}
  }

  @override
  void setActionWakeHandler(void Function()? handler) {
    _actionWakeHandler = handler;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onReminderAction') {
        _actionWakeHandler?.call();
      }
    });
  }

  Future<void> _scheduleWithPlugin(ScheduledReminderAlert alert) async {
    final id = notificationIdFor(alert.id);
    final details = NotificationDetails(android: _pluginDetails(alert));
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

  AndroidNotificationDetails _pluginDetails(ScheduledReminderAlert alert) {
    final path = alert.imagePath;
    if (path == null || path.isEmpty) return _channelDetails;
    final picture = FilePathAndroidBitmap(path);
    return AndroidNotificationDetails(
      _channelDetails.channelId,
      _channelDetails.channelName,
      channelDescription: _channelDetails.channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@drawable/ic_stat_notify',
      largeIcon: picture,
      styleInformation: BigPictureStyleInformation(
        picture,
        hideExpandedLargeIcon: true,
        contentTitle: alert.title,
        summaryText: alert.body,
      ),
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
