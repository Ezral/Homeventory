import 'package:flutter_test/flutter_test.dart';
import 'package:homeventory/features/inventory/data/inventory_repository.dart';
import 'package:homeventory/features/reminders/data/notification_scheduler.dart';
import 'package:homeventory/shared/models/enums.dart';
import 'package:homeventory/shared/models/reminder.dart';
import 'package:homeventory/shared/utils/reminder_schedule.dart';

InventoryTransaction _use({required DateTime at, required double amount}) {
  return InventoryTransaction(
    id: at.millisecondsSinceEpoch.toString(),
    homeId: 'h1',
    inventoryNodeId: 'n1',
    transactionType: InventoryTransactionType.use,
    quantityDelta: -amount,
    quantityUnit: 'CC',
    createdByUserId: 'u1',
    createdAt: at,
  );
}

void main() {
  group('nextFireAt', () {
    test('once keeps the chosen clock time even if it is in the past', () {
      final from = DateTime(2026, 8, 26, 12);
      final first = DateTime(2026, 8, 20, 9);
      final next = nextFireAt(
        from: from,
        repeat: ReminderRepeat.once,
        fireMinute: minutesFromMidnight(hour: 9, minute: 0),
        firstAt: first,
      );
      expect(next, DateTime(2026, 8, 20, 9));
    });

    test('weekly advances from a past first date', () {
      final from = DateTime(2026, 8, 26, 12);
      final first = DateTime(2026, 8, 19, 9);
      final next = nextFireAt(
        from: from,
        repeat: ReminderRepeat.weekly,
        fireMinute: minutesFromMidnight(hour: 9, minute: 0),
        firstAt: first,
      );
      expect(next, DateTime(2026, 9, 2, 9));
    });

    test('monthly clamps day 31 into shorter months', () {
      final from = DateTime(2026, 1, 31, 10);
      final next = nextFireAt(
        from: from,
        repeat: ReminderRepeat.monthly,
        fireMinute: minutesFromMidnight(hour: 9, minute: 0),
        firstAt: DateTime(2026, 1, 31, 9),
      );
      expect(next.month, 2);
      expect(next.day, 28);
      expect(next.hour, 9);
    });

    test('custom days uses the interval', () {
      final from = DateTime(2026, 8, 26, 12);
      final next = nextFireAt(
        from: from,
        repeat: ReminderRepeat.customDays,
        fireMinute: minutesFromMidnight(hour: 8, minute: 30),
        intervalDays: 10,
        firstAt: DateTime(2026, 8, 20, 8, 30),
      );
      expect(next, DateTime(2026, 8, 30, 8, 30));
    });
  });

  group('forecastRefill', () {
    final now = DateTime(2026, 8, 26, 9);

    test('needs two Use events', () {
      final forecast = forecastRefill(
        transactions: [
          _use(at: now.subtract(const Duration(days: 3)), amount: 20),
        ],
        quantity: 100,
        leadDays: 2,
        now: now,
      );
      expect(forecast.isReliable, isFalse);
      expect(forecast.confidenceLabel, 'Too little history');
    });

    test('estimates empty date from Use rate', () {
      final forecast = forecastRefill(
        transactions: [
          _use(at: DateTime(2026, 8, 12, 9), amount: 50),
          _use(at: DateTime(2026, 8, 22, 9), amount: 50),
        ],
        quantity: 100,
        leadDays: 2,
        now: now,
      );
      expect(forecast.isReliable, isTrue);
      expect(forecast.dailyUsage, 10);
      expect(forecast.emptyAt, DateTime(2026, 9, 5, 9));
      expect(forecast.notifyAt, DateTime(2026, 9, 3, 9));
      expect(forecast.explanation, contains('10 CC/day'));
    });

    test('ignores restock when averaging Use', () {
      final forecast = forecastRefill(
        transactions: [
          _use(at: DateTime(2026, 8, 12, 9), amount: 40),
          InventoryTransaction(
            id: 'r1',
            homeId: 'h1',
            inventoryNodeId: 'n1',
            transactionType: InventoryTransactionType.restock,
            quantityDelta: 200,
            createdByUserId: 'u1',
            createdAt: DateTime(2026, 8, 18, 9),
          ),
          _use(at: DateTime(2026, 8, 22, 9), amount: 40),
        ],
        quantity: 80,
        leadDays: 1,
        now: now,
      );
      expect(forecast.dailyUsage, 8);
    });
  });

  group('completeSchedule', () {
    test('once archives', () {
      final result = completeSchedule(
        repeat: ReminderRepeat.once,
        fireMinute: minutesFromMidnight(hour: 9, minute: 0),
        currentNext: DateTime(2026, 8, 20, 9),
        now: DateTime(2026, 8, 26, 12),
      );
      expect(result.archive, isTrue);
      expect(result.nextFireAt, isNull);
    });

    test('weekly early complete skips the current fire', () {
      final result = completeSchedule(
        repeat: ReminderRepeat.weekly,
        fireMinute: minutesFromMidnight(hour: 9, minute: 0),
        currentNext: DateTime(2026, 9, 2, 9),
        now: DateTime(2026, 8, 26, 12),
      );
      expect(result.archive, isFalse);
      expect(result.nextFireAt, DateTime(2026, 9, 9, 9));
    });

    test('weekly due complete advances from now', () {
      final result = completeSchedule(
        repeat: ReminderRepeat.weekly,
        fireMinute: minutesFromMidnight(hour: 9, minute: 0),
        currentNext: DateTime(2026, 8, 20, 9),
        now: DateTime(2026, 8, 26, 12),
      );
      expect(result.archive, isFalse);
      expect(result.nextFireAt, DateTime(2026, 8, 27, 9));
    });
  });

  group('Reminder', () {
    test('fromJson maps clothing-style node embed and due state', () {
      final reminder = Reminder.fromJson({
        'id': 'r1',
        'home_id': 'h1',
        'created_by_user_id': 'u1',
        'kind': 'USAGE_REFILL',
        'title': 'Refill soap',
        'body': null,
        'repeat': 'ONCE',
        'interval_days': null,
        'fire_minute': 540,
        'next_fire_at': '2020-01-01T09:00:00Z',
        'inventory_node_id': 'n1',
        'lead_days': 2,
        'enabled': true,
        'inventory_nodes': {
          'name': 'Bathroom soap',
          'quantity': 80,
          'quantity_unit': 'CC',
          'room_id': 'room-1',
          'is_container': false,
        },
      });
      expect(reminder.kind, ReminderKind.usageRefill);
      expect(reminder.nodeName, 'Bathroom soap');
      expect(reminder.fireHour, 9);
      expect(reminder.isDue, isTrue);
      expect(reminder.repeatSummary, 'Once');
      expect(reminder.isArchived, isFalse);
      expect(reminder.itemRoute, '/homes/h1/rooms/room-1/nodes/n1/details');
    });

    test('archived reminders are not due', () {
      final reminder = Reminder.fromJson({
        'id': 'r2',
        'home_id': 'h1',
        'created_by_user_id': 'u1',
        'kind': 'MANUAL',
        'title': 'Once',
        'repeat': 'ONCE',
        'fire_minute': 540,
        'next_fire_at': '2020-01-01T09:00:00Z',
        'inventory_node_id': 'n1',
        'enabled': false,
        'archived_at': '2026-08-26T09:00:00Z',
        'inventory_nodes': {
          'name': 'Cabinet',
          'room_id': 'room-1',
          'is_container': true,
        },
      });
      expect(reminder.isArchived, isTrue);
      expect(reminder.isDue, isFalse);
      expect(reminder.itemRoute, '/homes/h1/rooms/room-1/nodes/n1');
    });
  });

  test('notification ids stay in the signed 32-bit range', () {
    final id = notificationIdFor('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
    expect(id, greaterThanOrEqualTo(0));
    expect(id, lessThanOrEqualTo(0x7fffffff));
  });
}
