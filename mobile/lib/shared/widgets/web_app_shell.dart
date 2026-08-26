import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/web_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../features/homes/presentation/homes_providers.dart';
import 'home_invite_sheet.dart';
import 'user_menu_button.dart';

/// Desktop-web chrome: left sidebar + framed content pane.
///
/// Only used when [isWebDesktopLayout] is true. Mobile web and Android
/// render child screens unchanged (with bottom nav).
class WebAppShell extends ConsumerWidget {
  const WebAppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeId = homeIdFromLocation(location);
    final homeAsync = homeId == null ? null : ref.watch(homeProvider(homeId));
    final canEdit =
        homeAsync?.maybeWhen(
          data: (h) => h.myRole?.canEditInventory ?? false,
          orElse: () => false,
        ) ??
        false;
    final canInvite =
        homeAsync?.maybeWhen(
          data: (h) => h.myRole?.canManageMembers ?? false,
          orElse: () => false,
        ) ??
        false;
    final homeName = homeAsync?.maybeWhen(
      data: (h) => h.name,
      orElse: () => null,
    );

    final onHomes = location == '/';
    final onJoin = location.startsWith('/homes/join');
    final onHomeOverview = homeId != null && location == '/homes/$homeId';
    final onSearch =
        homeId != null && location.startsWith('/homes/$homeId/search');
    final onSchedule =
        homeId != null &&
        (location.startsWith('/homes/$homeId/schedule') ||
            location.startsWith('/homes/$homeId/reminders'));
    final onActivity =
        homeId != null && location.startsWith('/homes/$homeId/activity');
    final onTrips =
        homeId != null && location.startsWith('/homes/$homeId/trips');

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Row(
        children: [
          _Sidebar(
            homeId: homeId,
            homeName: homeName,
            canEdit: canEdit,
            canInvite: canInvite,
            onHomes: onHomes,
            onJoin: onJoin,
            onHomeOverview: onHomeOverview,
            onSearch: onSearch,
            onSchedule: onSchedule,
            onActivity: onActivity,
            onTrips: onTrips,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.paperElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.homeId,
    required this.homeName,
    required this.canEdit,
    required this.canInvite,
    required this.onHomes,
    required this.onJoin,
    required this.onHomeOverview,
    required this.onSearch,
    required this.onSchedule,
    required this.onActivity,
    required this.onTrips,
  });

  final String? homeId;
  final String? homeName;
  final bool canEdit;
  final bool canInvite;
  final bool onHomes;
  final bool onJoin;
  final bool onHomeOverview;
  final bool onSearch;
  final bool onSchedule;
  final bool onActivity;
  final bool onTrips;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 248,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.mossDeep,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
            child: Text(
              'Homeventory',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              'Map of everything at home',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
          _NavTile(
            icon: Icons.home_work_outlined,
            selectedIcon: Icons.home_work,
            label: 'All homes',
            selected: onHomes,
            onTap: () => context.go('/'),
          ),
          _NavTile(
            icon: Icons.qr_code_2_outlined,
            selectedIcon: Icons.qr_code_2,
            label: 'Join with invite',
            selected: onJoin,
            onTap: () => context.push('/homes/join'),
          ),
          if (homeId != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                homeName ?? 'This home',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.55),
                  letterSpacing: 0.4,
                ),
              ),
            ),
            _NavTile(
              icon: Icons.dashboard_outlined,
              selectedIcon: Icons.dashboard,
              label: 'Overview',
              selected: onHomeOverview,
              onTap: () => context.go('/homes/$homeId'),
            ),
            _NavTile(
              icon: Icons.search,
              selectedIcon: Icons.search,
              label: 'Search',
              selected: onSearch,
              onTap: () => context.go('/homes/$homeId/search'),
            ),
            _NavTile(
              icon: Icons.schedule,
              selectedIcon: Icons.schedule,
              label: 'Schedule',
              selected: onSchedule,
              onTap: () => context.go('/homes/$homeId/schedule'),
            ),
            _NavTile(
              icon: Icons.history,
              selectedIcon: Icons.history,
              label: 'Activity',
              selected: onActivity,
              onTap: () => context.go('/homes/$homeId/activity'),
            ),
            _NavTile(
              icon: Icons.luggage_outlined,
              selectedIcon: Icons.luggage,
              label: 'Trips',
              selected: onTrips,
              onTap: () => context.go('/homes/$homeId/trips'),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                ),
                onPressed: !canInvite
                    ? null
                    : () => showHomeInviteSheet(
                        context: context,
                        ref: ref,
                        homeId: homeId!,
                      ),
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: const Text('Invite'),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.mossSoft,
                  foregroundColor: AppColors.mossDeep,
                ),
                onPressed: !canEdit
                    ? null
                    : () => context.push('/homes/$homeId/rooms/new'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add room'),
              ),
            ),
          ],
          const Spacer(),
          const Divider(color: Color(0x33FFFFFF), height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Theme(
              data: Theme.of(context).copyWith(
                iconButtonTheme: IconButtonThemeData(
                  style: IconButton.styleFrom(foregroundColor: Colors.white),
                ),
              ),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: UserMenuButton(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: 22,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
