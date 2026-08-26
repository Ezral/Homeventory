import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/web_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/home_shell_bottom_nav.dart';
import '../../../shared/widgets/user_menu_button.dart';
import '../../homes/presentation/homes_providers.dart';
import 'activity_providers.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key, required this.homeId});

  final String homeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(homeActivityProvider(homeId));
    final canEdit = ref
        .watch(homeProvider(homeId))
        .maybeWhen(
          data: (h) => h.myRole?.canEditInventory ?? false,
          orElse: () => false,
        );
    final desktop = isWebDesktopLayout(context);
    final dateFormat = DateFormat.yMMMd().add_jm();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [if (!desktop) const UserMenuButton()],
      ),
      bottomNavigationBar: desktop
          ? null
          : HomeShellBottomNav(
              selectedIndex: HomeShellNav.home,
              addLabel: 'Add room',
              onSelect: (index) => handleHomeShellSelect(
                context: context,
                homeId: homeId,
                index: index,
                canEdit: canEdit,
                addDeniedMessage: 'You do not have permission to add rooms.',
                onAdd: () => context.push('/homes/$homeId/rooms/new'),
              ),
            ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(homeActivityProvider(homeId)),
        ),
        data: (events) {
          if (events.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              title: 'No activity yet',
              message:
                  'Creates, joins, rooms, items, and schedules for this home will show up here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(homeActivityProvider(homeId));
              await ref.read(homeActivityProvider(homeId).future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              itemCount: events.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final event = events[index];
                return SoftTile(
                  leading: Icon(
                    _iconFor(event.action),
                    color: AppColors.mossDeep,
                  ),
                  title: event.summary,
                  subtitle: dateFormat.format(event.createdAt.toLocal()),
                  trailing: const SizedBox.shrink(),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

IconData _iconFor(String action) {
  return switch (action) {
    'CREATE_HOME' || 'UPDATE_HOME' => Icons.home_work_outlined,
    'ARCHIVE_HOME' => Icons.archive_outlined,
    'JOIN_HOME' => Icons.person_add_alt_1_outlined,
    'REMOVE_MEMBER' => Icons.person_off_outlined,
    'INVITE_MEMBER' => Icons.mail_outline,
    'CREATE_ROOM' || 'UPDATE_ROOM' => Icons.meeting_room_outlined,
    'ARCHIVE_ROOM' || 'DELETE_ROOM' => Icons.meeting_room_outlined,
    'CREATE_NODE' || 'UPDATE_NODE' || 'MOVE_NODE' => Icons.inventory_2_outlined,
    'DISPOSE_NODE' || 'ARCHIVE_NODE' || 'DELETE_NODE' => Icons.delete_outline,
    'CREATE_SCHEDULE' => Icons.schedule,
    'COMPLETE_SCHEDULE' => Icons.check_circle_outline,
    'DELETE_SCHEDULE' => Icons.alarm_off_outlined,
    _ => Icons.history,
  };
}
