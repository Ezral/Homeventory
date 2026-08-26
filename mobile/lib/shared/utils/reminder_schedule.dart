import '../models/enums.dart';
import '../../features/inventory/data/inventory_repository.dart';

int minutesFromMidnight({required int hour, required int minute}) {
  return hour * 60 + minute;
}

DateTime dateAtFireMinute(DateTime day, int fireMinute) {
  final clamped = fireMinute.clamp(0, 1439);
  return DateTime(day.year, day.month, day.day, clamped ~/ 60, clamped % 60);
}

DateTime addCalendarMonths(DateTime from, int months) {
  var year = from.year;
  var month = from.month + months;
  while (month > 12) {
    year += 1;
    month -= 12;
  }
  while (month < 1) {
    year -= 1;
    month += 12;
  }
  final lastDay = DateTime(year, month + 1, 0).day;
  final day = from.day > lastDay ? lastDay : from.day;
  return DateTime(year, month, day, from.hour, from.minute, from.second);
}

/// Next fire at or after [from]. Once-reminders in the past stay in the past
/// so the UI can show them as due.
DateTime nextFireAt({
  required DateTime from,
  required ReminderRepeat repeat,
  required int fireMinute,
  int? intervalDays,
  DateTime? firstAt,
}) {
  final seed = firstAt ?? from;
  var candidate = dateAtFireMinute(seed, fireMinute);

  if (repeat == ReminderRepeat.once) {
    return candidate;
  }

  var guard = 0;
  while (!candidate.isAfter(from) && guard < 400) {
    candidate = switch (repeat) {
      ReminderRepeat.once => candidate,
      ReminderRepeat.daily => candidate.add(const Duration(days: 1)),
      ReminderRepeat.weekly => candidate.add(const Duration(days: 7)),
      ReminderRepeat.monthly => addCalendarMonths(candidate, 1),
      ReminderRepeat.customDays => candidate.add(
        Duration(days: (intervalDays ?? 1).clamp(1, 365)),
      ),
    };
    guard++;
  }
  return candidate;
}

class UsageForecast {
  const UsageForecast({
    required this.sampleCount,
    required this.spanDays,
    this.dailyUsage,
    this.emptyAt,
    this.notifyAt,
    required this.confidenceLabel,
    required this.explanation,
  });

  final int sampleCount;
  final double spanDays;
  final double? dailyUsage;
  final DateTime? emptyAt;
  final DateTime? notifyAt;
  final String confidenceLabel;
  final String explanation;

  bool get isReliable =>
      sampleCount >= 2 &&
      spanDays >= 1 &&
      dailyUsage != null &&
      dailyUsage! > 0 &&
      emptyAt != null;
}

/// Average daily Use from the USE ledger only (not restock or transfer refill).
UsageForecast forecastRefill({
  required List<InventoryTransaction> transactions,
  required double? quantity,
  required int leadDays,
  required DateTime now,
}) {
  final uses =
      transactions
          .where((t) => t.transactionType == InventoryTransactionType.use)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  if (uses.length < 2) {
    return UsageForecast(
      sampleCount: uses.length,
      spanDays: 0,
      confidenceLabel: 'Too little history',
      explanation:
          'Log at least two Use actions so we can estimate when this needs a refill.',
    );
  }

  final span = uses.last.createdAt.difference(uses.first.createdAt);
  final spanDays = span.inSeconds / 86400;
  if (spanDays < 1) {
    return UsageForecast(
      sampleCount: uses.length,
      spanDays: spanDays,
      confidenceLabel: 'Too little history',
      explanation:
          'Use actions are too close together. Keep logging Use over a few days.',
    );
  }

  final totalUsed = uses.fold<double>(
    0,
    (sum, t) => sum + (t.quantityDelta?.abs() ?? 0),
  );
  if (totalUsed <= 0) {
    return UsageForecast(
      sampleCount: uses.length,
      spanDays: spanDays,
      confidenceLabel: 'No usage yet',
      explanation: 'Use history has no quantity to average.',
    );
  }

  final daily = totalUsed / spanDays;
  final qty = (quantity ?? 0) < 0 ? 0.0 : (quantity ?? 0);
  final daysLeft = daily <= 0 ? 0.0 : qty / daily;
  final emptyAt = now.add(
    Duration(milliseconds: (daysLeft * 86400000).round()),
  );
  var notifyAt = emptyAt.subtract(Duration(days: leadDays.clamp(0, 365)));
  if (notifyAt.isBefore(now)) notifyAt = now;

  final unitHint = uses.first.quantityUnit;
  final dailyLabel = daily == daily.roundToDouble()
      ? daily.toInt().toString()
      : daily.toStringAsFixed(1);
  final daysLabel = daysLeft == daysLeft.roundToDouble()
      ? daysLeft.toInt().toString()
      : daysLeft.toStringAsFixed(1);

  return UsageForecast(
    sampleCount: uses.length,
    spanDays: spanDays,
    dailyUsage: daily,
    emptyAt: emptyAt,
    notifyAt: notifyAt,
    confidenceLabel: uses.length >= 5 && spanDays >= 7
        ? 'Steady'
        : 'Rough estimate',
    explanation:
        '$dailyLabel ${unitHint ?? 'units'}/day from ${uses.length} Use '
        'actions over ${spanDays.toStringAsFixed(0)} days. '
        'About $daysLabel days of stock left.',
  );
}
