import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:homeventory/features/reminders/data/notification_scheduler.dart';
import 'package:homeventory/features/reminders/data/reminder_image_cache.dart';
import 'package:homeventory/features/reminders/data/reminder_image_urls.dart';
import 'package:homeventory/shared/models/enums.dart';
import 'package:homeventory/shared/models/reminder.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Reminder _reminder({
  required String id,
  String? nodeId,
  String? roomId,
  String? nodeRoomId,
  String? nodeName,
  String? roomName,
  String? nodeRoomName,
  ReminderRepeat repeat = ReminderRepeat.weekly,
  int? intervalDays,
  bool enabled = true,
}) {
  return Reminder(
    id: id,
    homeId: 'h1',
    createdByUserId: 'u1',
    kind: ReminderKind.manual,
    title: 'Weekly Clean-up',
    body: 'Every week',
    repeat: repeat,
    intervalDays: intervalDays,
    fireMinute: 540,
    nextFireAt: DateTime(2026, 8, 30, 9),
    inventoryNodeId: nodeId,
    roomId: roomId,
    enabled: enabled,
    nodeName: nodeName,
    nodeRoomId: nodeRoomId,
    roomName: roomName,
    nodeRoomName: nodeRoomName,
  );
}

void main() {
  test('prefers the item photo over the room photo', () async {
    final pairs = await reminderImageUrls(
      reminders: [
        _reminder(
          id: 'r1',
          nodeId: 'n1',
          nodeRoomId: 'room-1',
          nodeName: 'Sink',
        ),
      ],
      latestImageUrls:
          ({
            required String homeId,
            required String entityType,
            required List<String> entityIds,
          }) async {
            if (entityType == 'INVENTORY_NODE') {
              return {'n1': 'https://img/node.jpg'};
            }
            return {'room-1': 'https://img/room.jpg'};
          },
    );
    expect(pairs.single.imageUrl, 'https://img/node.jpg');
  });

  test('falls back to the linked room photo', () async {
    final pairs = await reminderImageUrls(
      reminders: [_reminder(id: 'r2', roomId: 'room-1', roomName: 'Kitchen')],
      latestImageUrls:
          ({
            required String homeId,
            required String entityType,
            required List<String> entityIds,
          }) async {
            if (entityType == 'ROOM') {
              return {'room-1': 'https://img/kitchen.jpg'};
            }
            return {};
          },
    );
    expect(pairs.single.imageUrl, 'https://img/kitchen.jpg');
  });

  test("falls back to the item's room when the item has no photo", () async {
    final pairs = await reminderImageUrls(
      reminders: [
        _reminder(
          id: 'r3',
          nodeId: 'n1',
          nodeRoomId: 'room-1',
          nodeName: 'Lamp',
        ),
      ],
      latestImageUrls:
          ({
            required String homeId,
            required String entityType,
            required List<String> entityIds,
          }) async {
            if (entityType == 'ROOM') {
              return {'room-1': 'https://img/room.jpg'};
            }
            return {};
          },
    );
    expect(pairs.single.imageUrl, 'https://img/room.jpg');
  });

  test('skips disabled reminders when building native payloads', () async {
    final alerts = await scheduledAlertsWithImages(
      reminders: [
        _reminder(id: 'on', roomId: 'room-1', roomName: 'Kitchen'),
        _reminder(
          id: 'off',
          roomId: 'room-1',
          roomName: 'Kitchen',
          enabled: false,
        ),
      ],
      latestImageUrls:
          ({
            required String homeId,
            required String entityType,
            required List<String> entityIds,
          }) async {
            return {'room-1': 'https://img/kitchen.jpg'};
          },
    );
    expect(alerts, hasLength(1));
    expect(alerts.single.id, 'on');
    expect(alerts.single.imageUrl, 'https://img/kitchen.jpg');
    expect(alerts.single.targetLabel, 'Kitchen');
  });

  test(
    'native payload shows due one-offs now and does not reschedule them',
    () {
      final alert = ScheduledReminderAlert.fromReminder(
        _reminder(id: 'due').copyWithOnceDue(),
      );
      final payload = alert.toNativePayload(now: DateTime(2026, 8, 27, 10, 44));
      expect(payload['showNow'], isTrue);
      expect(payload['scheduleAtMillis'], isNull);
      expect(payload['repeat'], 'ONCE');
      expect(payload['title'], 'Weekly Clean-up');
      expect(payload['reminderId'], 'due');
      expect(payload['canSnooze'], isTrue);
      expect(payload['canMarkDone'], isTrue);
      expect(payload['displayAtMillis'], isNotNull);
    },
  );

  test(
    'native payload keeps weekly on the same weekday after a missed fire',
    () {
      final alert = ScheduledReminderAlert.fromReminder(
        _reminder(id: 'weekly', roomId: 'room-1', roomName: 'Kitchen'),
      );
      // next_fire_at is Sunday 30 Aug 09:00; "now" is Wednesday 2 Sep.
      final payload = alert.toNativePayload(now: DateTime(2026, 9, 2, 12));
      expect(payload['showNow'], isTrue);
      final scheduled = DateTime.fromMillisecondsSinceEpoch(
        payload['scheduleAtMillis'] as int,
      );
      expect(scheduled.weekday, DateTime.sunday);
      expect(scheduled.hour, 9);
    },
  );

  test('image cache writes bytes and reuses a fresh file', () async {
    final dir = await Directory.systemTemp.createTemp('reminder-photos');
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });
    var gets = 0;
    final cache = ReminderImageCache(
      directory: dir,
      client: MockClient((request) async {
        gets += 1;
        return http.Response.bytes([1, 2, 3, 4], 200);
      }),
    );
    final first = await cache.cacheUrl(
      reminderId: 'r1',
      url: 'https://img/kitchen.jpg',
    );
    final second = await cache.cacheUrl(
      reminderId: 'r1',
      url: 'https://img/kitchen.jpg',
    );
    expect(first, isNotNull);
    expect(second, first);
    expect(gets, 1);
    expect(File(first!).readAsBytesSync(), [1, 2, 3, 4]);
  });

  test(
    'payload includes item details, recurrence, route, and locale millis',
    () {
      final alert = ScheduledReminderAlert.fromReminder(
        _reminder(
          id: 'ac',
          nodeId: 'n-ac',
          nodeRoomId: 'room-bed',
          nodeName: 'Air conditioner',
          nodeRoomName: 'Bedroom',
          repeat: ReminderRepeat.customDays,
          intervalDays: 90,
        ),
      );
      expect(alert.details, 'Bedroom · Air conditioner');
      expect(alert.recurrence, 'Recurring every 90 days');
      expect(alert.route, '/homes/h1/rooms/room-bed/nodes/n-ac/details');
      final payload = alert.toNativePayload(now: DateTime(2026, 8, 27, 20));
      expect(payload['details'], 'Bedroom · Air conditioner');
      expect(payload['recurrence'], 'Recurring every 90 days');
      expect(payload['route'], '/homes/h1/rooms/room-bed/nodes/n-ac/details');
      expect(payload['itemOrRoomName'], 'Air conditioner');
      expect(payload['itemOrRoomId'], 'n-ac');
      expect(payload['reminderId'], 'ac');
      expect(
        payload['displayAtMillis'],
        DateTime(2026, 8, 30, 9).millisecondsSinceEpoch,
      );
    },
  );
}

extension on Reminder {
  Reminder copyWithOnceDue() {
    return Reminder(
      id: id,
      homeId: homeId,
      createdByUserId: createdByUserId,
      kind: ReminderKind.manual,
      title: title,
      body: body,
      repeat: ReminderRepeat.once,
      fireMinute: fireMinute,
      nextFireAt: DateTime(2026, 8, 26, 9),
      inventoryNodeId: inventoryNodeId,
      roomId: roomId,
      enabled: true,
      nodeName: nodeName,
      nodeRoomId: nodeRoomId,
      roomName: roomName,
    );
  }
}
