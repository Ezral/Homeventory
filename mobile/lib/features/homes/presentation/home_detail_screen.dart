import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/web_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/home.dart';
import '../../../shared/models/room.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/home_invite_sheet.dart';
import '../../../shared/widgets/home_shell_bottom_nav.dart';
import '../../../shared/widgets/user_menu_button.dart';
import '../../../shared/providers/supabase_provider.dart';
import '../../inventory/data/inventory_repository.dart';
import 'homes_providers.dart';
import '../../rooms/presentation/rooms_providers.dart';

class HomeDetailScreen extends ConsumerWidget {
  const HomeDetailScreen({super.key, required this.homeId});

  final String homeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeAsync = ref.watch(homeProvider(homeId));
    final roomsAsync = ref.watch(roomsListProvider(homeId));
    final statsAsync = ref.watch(homeDashboardStatsProvider(homeId));
    final membersAsync = ref.watch(homeMembersProvider(homeId));

    return homeAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(actions: const [UserMenuButton()]),
        body: ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(homeProvider(homeId)),
        ),
      ),
      data: (home) {
        final canEdit = home.myRole?.canEditInventory ?? false;
        final canInvite = home.myRole?.canManageMembers ?? false;
        final canEditHome = home.myRole?.isOwner ?? false;
        final homeImagesAsync = ref.watch(homeImagesProvider(homeId));
        final duration = home.residenceDurationLabel();
        final desktop = isWebDesktopLayout(context);

        return Scaffold(
          appBar: AppBar(
            // Name is shown next to the house image in the page header.
            title: const Text('Overview'),
            actions: [
              if (canEditHome)
                IconButton(
                  tooltip: 'Edit home',
                  onPressed: () async {
                    await context.push('/homes/$homeId/edit');
                    ref.invalidate(homeProvider(homeId));
                    ref.invalidate(homeImagesProvider(homeId));
                    ref.invalidate(homeDashboardStatsProvider(homeId));
                    ref.invalidate(homesListProvider);
                  },
                  icon: const Icon(Icons.edit_outlined),
                ),
              if (canEditHome)
                IconButton(
                  tooltip: 'Archive home',
                  onPressed: () => _confirmArchiveHome(
                    context: context,
                    ref: ref,
                    homeId: homeId,
                    homeName: home.name,
                  ),
                  icon: const Icon(Icons.archive_outlined),
                ),
              if (!desktop) const UserMenuButton(),
            ],
          ),
          floatingActionButton: desktop && canEdit
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    await context.push('/homes/$homeId/rooms/new');
                    ref.invalidate(roomsListProvider(homeId));
                    ref.invalidate(homeDashboardStatsProvider(homeId));
                  },
                  backgroundColor: AppColors.moss,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('Add room'),
                )
              : null,
          bottomNavigationBar: desktop
              ? null
              : HomeShellBottomNav(
                  selectedIndex: 2,
                  addLabel: 'Add room',
                  onSelect: (index) async {
                    switch (index) {
                      case 0:
                        await context.push('/homes/$homeId/search');
                      case 1:
                        await context.push('/homes/$homeId/trips');
                      case 2:
                        break;
                      case 3:
                        if (canInvite) {
                          await showHomeInviteSheet(
                            context: context,
                            ref: ref,
                            homeId: homeId,
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Only owners and admins can invite members.',
                              ),
                            ),
                          );
                        }
                      case 4:
                        if (!canEdit) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'You do not have permission to add rooms.',
                              ),
                            ),
                          );
                          return;
                        }
                        await context.push('/homes/$homeId/rooms/new');
                        ref.invalidate(roomsListProvider(homeId));
                        ref.invalidate(homeDashboardStatsProvider(homeId));
                    }
                  },
                ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(homeProvider(homeId));
              ref.invalidate(roomsListProvider(homeId));
              ref.invalidate(homeMembersProvider(homeId));
              ref.invalidate(homeImagesProvider(homeId));
              ref.invalidate(homeDashboardStatsProvider(homeId));
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _HomeOverviewHeader(
                    home: home,
                    homeId: homeId,
                    duration: duration,
                    homeImagesAsync: homeImagesAsync,
                    membersAsync: membersAsync,
                    statsAsync: statsAsync,
                    desktop: desktop,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionLabel('Rooms'),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
                roomsAsync.when(
                  loading: () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: ErrorView(
                      message: e.toString(),
                      onRetry: () => ref.invalidate(roomsListProvider(homeId)),
                    ),
                  ),
                  data: (rooms) {
                    if (rooms.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          icon: Icons.meeting_room_outlined,
                          title: 'No rooms yet',
                          message: canEdit
                              ? 'Add rooms like Kitchen, Bedroom, or Storage to start mapping inventory.'
                              : 'An editor needs to add rooms before you can browse inventory.',
                          actionLabel: canEdit ? 'Add room' : null,
                          onAction: canEdit
                              ? () => context.push('/homes/$homeId/rooms/new')
                              : null,
                        ),
                      );
                    }
                    final idsKey = rooms.map((r) => r.id).join(',');
                    final thumbsAsync = ref.watch(
                      entityThumbnailsProvider((
                        homeId: homeId,
                        entityType: 'ROOM',
                        idsKey: idsKey,
                      )),
                    );
                    final thumbs = thumbsAsync.maybeWhen(
                      data: (m) => m,
                      orElse: () => const <String, String>{},
                    );
                    return SliverPadding(
                      padding:
                          EdgeInsets.fromLTRB(20, 0, 20, desktop ? 32 : 100),
                      sliver: SliverGrid(
                        // 3∶2 landscape cover cards.
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: desktop ? 320 : 420,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 3 / 2,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final room = rooms[index];
                            return _RoomCoverCard(
                              homeId: homeId,
                              room: room,
                              imageUrl: thumbs[room.id],
                            );
                          },
                          childCount: rooms.length,
                        ),
                      ),
                    );
                  },
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, desktop ? 40 : 120),
                    child: _MembersManageSection(
                      homeId: homeId,
                      canManage: canInvite,
                      isOwner: canEditHome,
                      myRole: home.myRole,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<void> _confirmArchiveHome({
  required BuildContext context,
  required WidgetRef ref,
  required String homeId,
  required String homeName,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Archive $homeName?'),
      content: const Text(
        'It will leave your homes list. Inventory stays saved — '
        'open Settings → Archived homes to restore it.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Archive'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  try {
    await ref.read(homesRepositoryProvider).archiveHome(homeId);
    ref.invalidate(homesListProvider);
    ref.invalidate(hiddenHomesListProvider);
    ref.invalidate(activeHomeIdProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$homeName is archived')),
      );
      context.go('/');
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}

class _RoomCoverCard extends StatelessWidget {
  const _RoomCoverCard({
    required this.homeId,
    required this.room,
    required this.imageUrl,
  });

  final String homeId;
  final Room room;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/homes/$homeId/rooms/${room.id}'),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageUrl == null
                  ? const ColoredBox(
                      color: AppColors.mossSoft,
                      child: Center(
                        child: Icon(
                          Icons.meeting_room_outlined,
                          size: 40,
                          color: AppColors.mossDeep,
                        ),
                      ),
                    )
                  : Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: AppColors.mossSoft,
                        child: Center(
                          child: Icon(
                            Icons.meeting_room_outlined,
                            size: 40,
                            color: AppColors.mossDeep,
                          ),
                        ),
                      ),
                    ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0xCC1B3A2F),
                    ],
                    stops: [0.45, 1],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Text(
                  room.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeOverviewHeader extends ConsumerWidget {
  const _HomeOverviewHeader({
    required this.home,
    required this.homeId,
    required this.duration,
    required this.homeImagesAsync,
    required this.membersAsync,
    required this.statsAsync,
    required this.desktop,
  });

  final Home home;
  final String homeId;
  final String? duration;
  final AsyncValue<List<EntityImage>> homeImagesAsync;
  final AsyncValue<List<HomeMember>> membersAsync;
  final AsyncValue<HomeDashboardStats> statsAsync;
  final bool desktop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = homeImagesAsync.maybeWhen(
      data: (images) => images.isNotEmpty ? images.first.signedUrl : null,
      orElse: () => null,
    );
    final imageSize = desktop ? 168.0 : 128.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HomeImageThumb(imageUrl: imageUrl, size: imageSize),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      home.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    membersAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (members) => Text(
                        '${members.length} member${members.length == 1 ? '' : 's'}'
                        '${home.myRole != null ? ' · ${home.myRole!.label}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (duration != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        duration!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (home.addressText != null &&
                        home.addressText!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        home.addressText!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 10),
                    statsAsync.when(
                      loading: () => const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (stats) => _InlineHomeStats(stats: stats),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (home.description != null &&
              home.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              home.description!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _HomeImageThumb extends StatelessWidget {
  const _HomeImageThumb({required this.imageUrl, required this.size});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: size,
        height: size,
        child: imageUrl == null
            ? const ColoredBox(
                color: AppColors.mossSoft,
                child: Icon(Icons.home, color: AppColors.mossDeep, size: 36),
              )
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: AppColors.mossSoft,
                  child: Icon(Icons.home, color: AppColors.mossDeep, size: 36),
                ),
              ),
      ),
    );
  }
}

class _InlineHomeStats extends StatelessWidget {
  const _InlineHomeStats({required this.stats});

  final HomeDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final valueFormat = NumberFormat.compactCurrency(
      symbol: '${stats.valueCurrency} ',
      decimalDigits: 0,
    );
    final parts = [
      '${stats.roomsCount} room${stats.roomsCount == 1 ? '' : 's'}',
      '${stats.baseFurnitureCount} furniture',
      '${stats.itemsCount} item${stats.itemsCount == 1 ? '' : 's'}',
      '${valueFormat.format(stats.estimatedValue)} est.',
    ];

    return Text(
      parts.join(' · '),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.mossDeep,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _MembersManageSection extends ConsumerWidget {
  const _MembersManageSection({
    required this.homeId,
    required this.canManage,
    required this.isOwner,
    required this.myRole,
  });

  final String homeId;
  final bool canManage;
  final bool isOwner;
  final HomeRole? myRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(homeMembersProvider(homeId));
    final myUserId =
        ref.watch(supabaseClientProvider).auth.currentUser?.id;

    return membersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (members) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Member details'),
            const SizedBox(height: 10),
            if (members.isEmpty)
              Text(
                'No active members.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              for (final member in members)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SoftTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.mossSoft,
                      foregroundColor: AppColors.mossDeep,
                      backgroundImage: member.avatarUrl != null &&
                              member.avatarUrl!.isNotEmpty
                          ? NetworkImage(member.avatarUrl!)
                          : null,
                      child: member.avatarUrl == null ||
                              member.avatarUrl!.isEmpty
                          ? Text(member.initials)
                          : null,
                    ),
                    title: member.label,
                    subtitle: member.role.label,
                    trailing: _memberActions(
                      context,
                      ref,
                      member,
                      myUserId: myUserId,
                    ),
                  ),
                ),
            if (myRole != null && myRole != HomeRole.owner) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _confirmLeave(context, ref),
                child: const Text('Leave home'),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _memberActions(
    BuildContext context,
    WidgetRef ref,
    HomeMember member, {
    required String? myUserId,
  }) {
    final isSelf = myUserId != null && member.userId == myUserId;
    if (isSelf || member.role == HomeRole.owner) {
      return const SizedBox.shrink();
    }

    final canChangeRole = isOwner;
    final canTransfer = isOwner;
    final canRemove = canManage;

    if (!canChangeRole && !canTransfer && !canRemove) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<_MemberAction>(
      tooltip: 'Manage member',
      onSelected: (action) async {
        switch (action) {
          case _MemberAction.changeRole:
            await _pickRole(context, ref, member);
          case _MemberAction.transferOwnership:
            await _confirmTransfer(context, ref, member);
          case _MemberAction.remove:
            await _confirmRemove(context, ref, member);
        }
      },
      itemBuilder: (context) => [
        if (canChangeRole)
          const PopupMenuItem(
            value: _MemberAction.changeRole,
            child: Text('Change role'),
          ),
        if (canTransfer)
          const PopupMenuItem(
            value: _MemberAction.transferOwnership,
            child: Text('Transfer ownership'),
          ),
        if (canRemove)
          const PopupMenuItem(
            value: _MemberAction.remove,
            child: Text('Remove'),
          ),
      ],
    );
  }

  Future<void> _pickRole(
    BuildContext context,
    WidgetRef ref,
    HomeMember member,
  ) async {
    final roles = [
      HomeRole.admin,
      HomeRole.editor,
      HomeRole.viewer,
    ];
    final chosen = await showDialog<HomeRole>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Role for ${member.label}'),
        children: [
          for (final role in roles)
            ListTile(
              title: Text(role.label),
              subtitle: Text(_roleHint(role)),
              selected: member.role == role,
              trailing: member.role == role
                  ? const Icon(Icons.check, color: AppColors.moss)
                  : null,
              onTap: () => Navigator.pop(context, role),
            ),
        ],
      ),
    );
    if (chosen == null || chosen == member.role || !context.mounted) return;
    try {
      await ref.read(homesRepositoryProvider).setMemberRole(
            homeId: homeId,
            userId: member.userId,
            role: chosen,
          );
      ref.invalidate(homeMembersProvider(homeId));
      ref.invalidate(homeProvider(homeId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member.label} is now ${chosen.label}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  String _roleHint(HomeRole role) => switch (role) {
        HomeRole.admin => 'Invite members and manage access',
        HomeRole.editor => 'Add and edit inventory',
        HomeRole.viewer => 'View only',
        HomeRole.owner => 'Full control',
      };

  Future<void> _confirmTransfer(
    BuildContext context,
    WidgetRef ref,
    HomeMember member,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transfer ownership?'),
        content: Text(
          '${member.label} will become the Owner. '
          'You will become an Admin and can no longer transfer ownership '
          'unless they transfer it back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(homesRepositoryProvider).transferOwnership(
            homeId: homeId,
            userId: member.userId,
          );
      ref.invalidate(homeMembersProvider(homeId));
      ref.invalidate(homeProvider(homeId));
      ref.invalidate(homesListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ownership transferred to ${member.label}'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    HomeMember member,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text(
          '${member.label} will lose access to this home immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref
          .read(homesRepositoryProvider)
          .removeMember(homeId: homeId, userId: member.userId);
      ref.invalidate(homeMembersProvider(homeId));
      ref.invalidate(homeDashboardStatsProvider(homeId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _confirmLeave(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this home?'),
        content: const Text('You will lose access until invited again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(homesRepositoryProvider).leaveHome(homeId);
      ref.invalidate(homesListProvider);
      if (context.mounted) context.go('/');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}

enum _MemberAction { changeRole, transferOwnership, remove }
