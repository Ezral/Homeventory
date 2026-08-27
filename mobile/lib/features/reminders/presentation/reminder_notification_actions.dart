import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/reminder_deep_link.dart';
import 'reminders_providers.dart';

/// Consumes notification tap / Mark done extras once Flutter is running.
final reminderNotificationActionBinderProvider = Provider<void>((ref) {
  final scheduler = ref.read(reminderNotificationSchedulerProvider);

  Future<void> drain() async {
    final action = await scheduler.peekPendingAction();
    if (action == null) return;
    final type = action['type'] ?? '';
    final reminderId = action['reminderId'] ?? '';
    final route = action['route'] ?? '';
    if (type.isEmpty) {
      await scheduler.consumePendingAction();
      return;
    }
    if (reminderId.startsWith('debug-')) {
      await scheduler.consumePendingAction();
      if (type == 'open') {
        ref.read(routerProvider).go('/');
      }
      return;
    }
    final session = ref.read(currentSessionProvider);
    if (type == 'complete' && session == null) {
      return;
    }
    await scheduler.consumePendingAction();
    try {
      if (type == 'complete') {
        final repo = ref.read(remindersRepositoryProvider);
        final reminder = await repo.getReminder(reminderId);
        await repo.completeReminder(reminder);
        ref.invalidate(homeRemindersProvider(reminder.homeId));
        ref.invalidate(reminderAlarmSyncProvider);
      } else if (type == 'open') {
        final dest = route.trim();
        if (dest.isNotEmpty && dest.startsWith('/')) {
          final router = ref.read(routerProvider);
          if (session == null) {
            router.go(
              Uri(path: '/sign-in', queryParameters: {'next': dest}).toString(),
            );
          } else {
            openReminderDestination(router, dest);
          }
        }
      }
    } catch (e, st) {
      debugPrint('Reminder notification action failed: $e\n$st');
    }
  }

  scheduler.setActionWakeHandler(() {
    drain();
  });
  WidgetsBinding.instance.addPostFrameCallback((_) {
    drain();
  });
  ref.listen(currentSessionProvider, (_, _) {
    drain();
  });
  ref.onDispose(() => scheduler.setActionWakeHandler(null));
});
