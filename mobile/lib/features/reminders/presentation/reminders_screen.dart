import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/web_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/reminder.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/home_shell_bottom_nav.dart';
import '../../../shared/widgets/user_menu_button.dart';
import '../../homes/presentation/homes_providers.dart';
import 'edit_reminder_screen.dart';
import 'reminders_providers.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key, required this.homeId});

  final String homeId;

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  String? _completingId;

  String get homeId => widget.homeId;

  @override
  Widget build(BuildContext context) {
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
    final desktop = isWebDesktopLayout(context);

    ref.listen(homeRemindersProvider(homeId), (prev, next) {
      next.whenData((reminders) {
        syncReminderNotifications(ref, homeId: homeId, reminders: reminders);
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        actions: [if (!desktop) const UserMenuButton()],
      ),
      floatingActionButton: desktop && canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              backgroundColor: AppColors.moss,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add schedule'),
            )
          : null,
      bottomNavigationBar: desktop
          ? null
          : HomeShellBottomNav(
              selectedIndex: HomeShellNav.schedule,
              addLabel: 'Add',
              onSelect: (index) => handleHomeShellSelect(
                context: context,
                homeId: homeId,
                index: index,
                canEdit: canEdit,
                addDeniedMessage:
                    'You do not have permission to add schedules.',
                onAdd: () => _openEditor(),
              ),
            ),
      body: remindersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(homeRemindersProvider(homeId)),
        ),
        data: (reminders) {
          if (reminders.isEmpty) {
            return EmptyState(
              icon: Icons.schedule,
              title: 'Nothing scheduled yet',
              message: canEdit
                  ? 'Add an alarm on a room or item, or a refill from Use history. You can also set this when editing an item.'
                  : 'An editor can add cleanup alarms and refill notifications for this home.',
              actionLabel: canEdit ? 'Add schedule' : null,
              onAction: canEdit ? () => _openEditor() : null,
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
                  onTap: canEdit ? () => _openEditor(reminder: reminder) : null,
                  trailing: _trailing(reminder, canEdit),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _trailing(Reminder reminder, bool canEdit) {
    final completing = _completingId == reminder.id;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canEdit && reminder.enabled)
          IconButton(
            tooltip: 'Complete',
            onPressed: completing ? null : () => _complete(reminder),
            icon: completing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.checklist),
          ),
        if (canEdit)
          Switch(
            value: reminder.enabled,
            onChanged: completing ? null : (v) => _setEnabled(reminder, v),
          ),
        if (reminder.targetRoute != null)
          IconButton(
            tooltip: reminder.roomId != null ? 'Open room' : 'Open item',
            onPressed: () => context.push(reminder.targetRoute!),
            icon: const Icon(Icons.open_in_new),
          ),
      ],
    );
  }

  String _subtitle(Reminder reminder, DateFormat dateFormat) {
    final parts = <String>[
      if (reminder.targetName != null) reminder.targetName!,
      reminder.kind.label,
      reminder.repeatSummary,
      reminder.enabled
          ? (reminder.isDue
                ? 'Due now'
                : 'Next ${dateFormat.format(reminder.nextFireAt.toLocal())}')
          : 'Off',
    ];
    return parts.join(' · ');
  }

  Future<void> _setEnabled(Reminder reminder, bool enabled) async {
    await ref
        .read(remindersRepositoryProvider)
        .updateReminder(reminderId: reminder.id, enabled: enabled);
    ref.invalidate(homeRemindersProvider(homeId));
  }

  Future<void> _complete(Reminder reminder) async {
    if (_completingId != null) return;
    setState(() => _completingId = reminder.id);
    try {
      await ref.read(remindersRepositoryProvider).completeReminder(reminder);
      ref.invalidate(homeRemindersProvider(homeId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reminder.isRepeating
                ? 'Done. Next time is scheduled.'
                : 'Archived this one-off schedule.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _completingId = null);
    }
  }

  Future<void> _openEditor({Reminder? reminder}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditReminderScreen(homeId: homeId, existing: reminder),
      ),
    );
    ref.invalidate(homeRemindersProvider(homeId));
  }
}
