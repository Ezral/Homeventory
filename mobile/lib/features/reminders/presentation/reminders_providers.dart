import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/reminder.dart';
import '../../../shared/providers/supabase_provider.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../homes/presentation/homes_providers.dart';
import '../data/notification_scheduler.dart';
import '../data/notification_scheduler_stub.dart'
    if (dart.library.io) '../data/notification_scheduler_io.dart'
    if (dart.library.js_interop) '../data/notification_scheduler_web.dart';
import '../data/reminders_repository.dart';

final remindersRepositoryProvider = Provider<RemindersRepository>((ref) {
  return RemindersRepository(ref.watch(supabaseClientProvider));
});

final reminderNotificationSchedulerProvider =
    Provider<ReminderNotificationScheduler>((ref) {
      return createReminderNotificationScheduler();
    });

/// Schedules Android local alerts for every enabled reminder after sign-in.
/// Without this, alarms are only armed if the user opens Schedule or saves one.
final reminderAlarmSyncProvider = FutureProvider<void>((ref) async {
  final session = ref.watch(currentSessionProvider);
  final scheduler = ref.read(reminderNotificationSchedulerProvider);
  if (session == null) {
    await scheduler.sync(const []);
    return;
  }
  try {
    final homes = await ref.read(homesRepositoryProvider).listVisibleHomes();
    final repo = ref.read(remindersRepositoryProvider);
    final alerts = <ScheduledReminderAlert>[];
    for (final home in homes) {
      final reminders = await repo.listReminders(home.id);
      alerts.addAll(
        reminders
            .where((r) => r.enabled)
            .map(ScheduledReminderAlert.fromReminder),
      );
    }
    await scheduler.sync(alerts);
  } catch (e, st) {
    debugPrint('Reminder alarm sync failed: $e\n$st');
  }
});

final homeRemindersProvider = FutureProvider.autoDispose
    .family<List<Reminder>, String>((ref, homeId) {
      return ref.watch(remindersRepositoryProvider).listReminders(homeId);
    });

final reminderProvider = FutureProvider.autoDispose.family<Reminder, String>((
  ref,
  reminderId,
) {
  return ref.watch(remindersRepositoryProvider).getReminder(reminderId);
});
