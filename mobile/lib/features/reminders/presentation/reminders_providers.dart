import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/reminder.dart';
import '../../../shared/providers/supabase_provider.dart';
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
