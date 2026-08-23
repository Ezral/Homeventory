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
import '../../../shared/widgets/entity_thumbnail.dart';
import '../../../shared/widgets/home_invite_sheet.dart';
import '../../../shared/widgets/home_shell_bottom_nav.dart';
import '../../../shared/widgets/user_menu_button.dart';
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
            title: Text(desktop ? home.name : 'Home'),
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
                  child: _FacebookStyleHomeHeader(
                    home: home,
                    homeId: homeId,
                    duration: duration,
                    canInvite: canInvite,
                    canEditHome: canEditHome,
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
                      padding: EdgeInsets.fromLTRB(20, 0, 20, desktop ? 32 : 100),
                      sliver: desktop
                          ? SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 280,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.55,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final room = rooms[index];
                                  return _RoomCard(
                                    homeId: homeId,
                                    room: room,
                                    imageUrl: thumbs[room.id],
                                    canEdit: canEdit,
                                    onEdited: () {
                                      ref.invalidate(roomsListProvider(homeId));
                                      ref.invalidate(
                                        homeDashboardStatsProvider(homeId),
                                      );
                                    },
                                  );
                                },
                                childCount: rooms.length,
                              ),
                            )
                          : SliverList.separated(
                              itemCount: rooms.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final room = rooms[index];
                                return SoftTile(
                                  leading: EntityThumbnail(
                                    imageUrl: thumbs[room.id],
                                    fallback: Icons.meeting_room_outlined,
                                  ),
                                  title: room.name,
                                  subtitle: room.description,
                                  trailing: canEdit
                                      ? IconButton(
                                          tooltip: 'Edit room',
                                          icon: const Icon(Icons.edit_outlined),
                                          color: AppColors.inkMuted,
                                          onPressed: () async {
                                            await context.push(
                                              '/homes/$homeId/rooms/${room.id}/edit',
                                            );
                                            ref.invalidate(
                                              roomsListProvider(homeId),
                                            );
                                            ref.invalidate(
                                              homeDashboardStatsProvider(homeId),
                                            );
                                          },
                                        )
                                      : null,
                                  onTap: () => context.push(
                                    '/homes/$homeId/rooms/${room.id}',
                                  ),
                                );
                              },
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

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.homeId,
    required this.room,
    required this.imageUrl,
    required this.canEdit,
    required this.onEdited,
  });

  final String homeId;
  final Room room;
  final String? imageUrl;
  final bool canEdit;
  final VoidCallback onEdited;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/homes/$homeId/rooms/${room.id}'),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    EntityThumbnail(
                      imageUrl: imageUrl,
                      fallback: Icons.meeting_room_outlined,
                    ),
                    const Spacer(),
                    if (canEdit)
                      IconButton(
                        tooltip: 'Edit room',
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        color: AppColors.inkMuted,
                        onPressed: () async {
                          await context.push(
                            '/homes/$homeId/rooms/${room.id}/edit',
                          );
                          onEdited();
                        },
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  room.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (room.description != null &&
                    room.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    room.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FacebookStyleHomeHeader extends ConsumerWidget {
  const _FacebookStyleHomeHeader({
    required this.home,
    required this.homeId,
    required this.duration,
    required this.canInvite,
    required this.canEditHome,
    required this.homeImagesAsync,
    required this.membersAsync,
    required this.statsAsync,
    required this.desktop,
  });

  final Home home;
  final String homeId;
  final String? duration;
  final bool canInvite;
  final bool canEditHome;
  final AsyncValue<List<EntityImage>> homeImagesAsync;
  final AsyncValue<List<HomeMember>> membersAsync;
  final AsyncValue<HomeDashboardStats> statsAsync;
  final bool desktop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverUrl = homeImagesAsync.maybeWhen(
      data: (images) => images.isNotEmpty ? images.first.signedUrl : null,
      orElse: () => null,
    );
    final coverHeight = desktop ? 180.0 : 140.0;
    final avatarSize = desktop ? 88.0 : 72.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              height: coverHeight,
              width: double.infinity,
              child: coverUrl == null
                  ? const ColoredBox(color: AppColors.mossSoft)
                  : Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: coverHeight,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: AppColors.mossSoft),
                    ),
            ),
            Positioned(
              left: 16,
              bottom: -(avatarSize / 2),
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.paperElevated, width: 4),
                  color: AppColors.mossSoft,
                ),
                clipBehavior: Clip.antiAlias,
                child: coverUrl == null
                    ? Icon(
                        Icons.home,
                        size: avatarSize * 0.45,
                        color: AppColors.mossDeep,
                      )
                    : Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.home,
                          size: avatarSize * 0.45,
                          color: AppColors.mossDeep,
                        ),
                      ),
              ),
            ),
          ],
        ),
        SizedBox(height: avatarSize / 2 + 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      home.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    membersAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (members) => Row(
                        children: [
                          Flexible(
                            child: _MemberAvatarRow(members: members),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${members.length} member${members.length == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (duration != null) ...[
                      const SizedBox(height: 4),
                      Text(duration!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                    if (home.addressText != null &&
                        home.addressText!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        home.addressText!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  if (canInvite)
                    FilledButton.icon(
                      onPressed: () => showHomeInviteSheet(
                        context: context,
                        ref: ref,
                        homeId: homeId,
                      ),
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('Invite'),
                    ),
                  if (canEditHome)
                    OutlinedButton.icon(
                      onPressed: () async {
                        await context.push('/homes/$homeId/edit');
                        ref.invalidate(homeProvider(homeId));
                        ref.invalidate(homeImagesProvider(homeId));
                        ref.invalidate(homeDashboardStatsProvider(homeId));
                        ref.invalidate(homesListProvider);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (home.description != null &&
            home.description!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              home.description!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: statsAsync.when(
            loading: () => const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Text(
              'Dashboard unavailable: $e',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            data: (stats) => _DashboardStrip(stats: stats, desktop: desktop),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, color: AppColors.line),
      ],
    );
  }
}

class _MemberAvatarRow extends StatelessWidget {
  const _MemberAvatarRow({required this.members});

  final List<HomeMember> members;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: members.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final member = members[index];
          final url = member.avatarUrl;
          return Tooltip(
            message: member.label,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.mossSoft,
              foregroundColor: AppColors.mossDeep,
              backgroundImage:
                  url != null && url.isNotEmpty ? NetworkImage(url) : null,
              child: url == null || url.isEmpty
                  ? Text(
                      member.initials,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _DashboardStrip extends StatelessWidget {
  const _DashboardStrip({required this.stats, required this.desktop});

  final HomeDashboardStats stats;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final valueFormat = NumberFormat.compactCurrency(
      symbol: '${stats.valueCurrency} ',
      decimalDigits: 0,
    );
    final items = [
      (label: 'Rooms', value: '${stats.roomsCount}'),
      (label: 'Furniture', value: '${stats.baseFurnitureCount}'),
      (label: 'Items', value: '${stats.itemsCount}'),
      (label: 'Est. value', value: valueFormat.format(stats.estimatedValue)),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.mossSoft.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(width: 1, height: 28, color: AppColors.line),
            Expanded(
              child: Column(
                children: [
                  Text(
                    items[i].value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    items[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.inkMuted,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MembersManageSection extends ConsumerWidget {
  const _MembersManageSection({
    required this.homeId,
    required this.canManage,
    required this.myRole,
  });

  final String homeId;
  final bool canManage;
  final HomeRole? myRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(homeMembersProvider(homeId));
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
                    trailing: canManage && member.role != HomeRole.owner
                        ? IconButton(
                            tooltip: 'Remove member',
                            icon: const Icon(Icons.person_remove_outlined),
                            onPressed: () =>
                                _confirmRemove(context, ref, member),
                          )
                        : const SizedBox.shrink(),
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
