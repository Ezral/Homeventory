import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/reminder.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../homes/presentation/homes_providers.dart';
import '../data/notification_scheduler.dart';
import 'edit_reminder_screen.dart';
import 'reminders_providers.dart';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key, required this.homeId});

  final String homeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = ref
        .watch(homeProvider(homeId))
        .maybeWhen(
          data: (h) => h.myRole?.canEditInventory ?? false,
          orElse: () => false,
        );
    final remindersAsync = ref.watch(homeRemindersProvider(homeId));
    final scheduler = ref.watch(reminderNotificationSchedulerProvider);
    scheduler.initialize();
    final dateFormat = DateFormat.yMMMd().add_jm();

    ref.listen(homeRemindersProvider(homeId), (prev, next) {
      next.whenData((reminders) {
        scheduler.sync(
          reminders
              .where((r) => r.enabled)
              .map(ScheduledReminderAlert.fromReminder)
              .toList(),
        );
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(context, ref),
              backgroundColor: AppColors.moss,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add reminder'),
            )
          : null,
      body: remindersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(homeRemindersProvider(homeId)),
        ),
        data: (reminders) {
          if (reminders.isEmpty) {
            return EmptyState(
              icon: Icons.notifications_outlined,
              title: 'No reminders yet',
              message: canEdit
                  ? 'Add a weekly or monthly alarm with your own text, or a refill reminder based on Use history.'
                  : 'An editor can add cleanup alarms and refill reminders for this home.',
              actionLabel: canEdit ? 'Add reminder' : null,
              onAction: canEdit ? () => _openEditor(context, ref) : null,
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              Text(
                scheduler.platformNote,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              const SectionLabel('Scheduled'),
              const SizedBox(height: 10),
              for (final reminder in reminders) ...[
                SoftTile(
                  leading: Icon(
                    reminder.kind == ReminderKind.usageRefill
                        ? Icons.water_drop_outlined
                        : Icons.alarm,
                    color: reminder.enabled
                        ? AppColors.mossDeep
                        : AppColors.inkMuted,
                  ),
                  title: reminder.title,
                  subtitle: _subtitle(reminder, dateFormat),
                  dimmed: !reminder.enabled,
                  onTap: canEdit
                      ? () => _openEditor(context, ref, reminder: reminder)
                      : null,
                  trailing: canEdit
                      ? Switch(
                          value: reminder.enabled,
                          onChanged: (v) => _setEnabled(ref, reminder, v),
                        )
                      : null,
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }

  String _subtitle(Reminder reminder, DateFormat dateFormat) {
    final parts = <String>[
      reminder.kind.label,
      reminder.repeatSummary,
      if (reminder.kind == ReminderKind.usageRefill &&
          reminder.nodeName != null)
        reminder.nodeName!,
      reminder.enabled
          ? (reminder.isDue
                ? 'Due now'
                : 'Next ${dateFormat.format(reminder.nextFireAt.toLocal())}')
          : 'Off',
    ];
    return parts.join(' · ');
  }

  Future<void> _setEnabled(
    WidgetRef ref,
    Reminder reminder,
    bool enabled,
  ) async {
    await ref
        .read(remindersRepositoryProvider)
        .updateReminder(reminderId: reminder.id, enabled: enabled);
    ref.invalidate(homeRemindersProvider(homeId));
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    Reminder? reminder,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditReminderScreen(homeId: homeId, existing: reminder),
      ),
    );
    ref.invalidate(homeRemindersProvider(homeId));
  }
}
