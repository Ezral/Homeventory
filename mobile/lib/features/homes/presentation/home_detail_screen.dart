import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/home.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/entity_thumbnail.dart';
import '../../../shared/widgets/home_invite_sheet.dart';
import '../../../shared/widgets/home_shell_bottom_nav.dart';
import '../../../shared/widgets/user_menu_button.dart';
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

        return Scaffold(
          appBar: AppBar(
            title: const Text('Home'),
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
              const UserMenuButton(),
            ],
          ),
          floatingActionButton: null,
          bottomNavigationBar: HomeShellBottomNav(
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
                        content: Text('You do not have permission to add rooms.'),
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
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        homeImagesAsync.when(
                          loading: () => const _HomeCoverFallback(),
                          error: (_, _) => const _HomeCoverFallback(),
                          data: (images) {
                            final url = images.isNotEmpty
                                ? images.first.signedUrl
                                : null;
                            if (url == null) return const _HomeCoverFallback();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const _HomeCoverFallback(
                                      asAspectRatio: false,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        Text(
                          home.name,
                          style: Theme.of(context).textTheme.headlineMedium,
                          softWrap: true,
                        ),
                        const SizedBox(height: 12),
                        membersAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (members) => _MemberAvatarRow(members: members),
                        ),
                        if (duration != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            duration,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                        if (home.description != null &&
                            home.description!.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            home.description!,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                        if (home.remarks != null &&
                            home.remarks!.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            home.remarks!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                        if (home.addressText != null &&
                            home.addressText!.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            home.addressText!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.inkMuted),
                          ),
                        ],
                        const SizedBox(height: 20),
                        statsAsync.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (e, _) => Text(
                            'Dashboard unavailable: $e',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          data: (stats) => _DashboardGrid(stats: stats),
                        ),
                        const SizedBox(height: 24),
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
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      sliver: SliverList.separated(
                        itemCount: rooms.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
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
                                      ref.invalidate(roomsListProvider(homeId));
                                      ref.invalidate(
                                        homeDashboardStatsProvider(homeId),
                                      );
                                      ref.invalidate(
                                        entityThumbnailsProvider((
                                          homeId: homeId,
                                          entityType: 'ROOM',
                                          idsKey: idsKey,
                                        )),
                                      );
                                    },
                                  )
                                : null,
                            onTap: () =>
                                context.push('/homes/$homeId/rooms/${room.id}'),
                          );
                        },
                      ),
                    );
                  },
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
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

class _HomeCoverFallback extends StatelessWidget {
  const _HomeCoverFallback({this.asAspectRatio = true});

  final bool asAspectRatio;

  @override
  Widget build(BuildContext context) {
    final child = ColoredBox(
      color: AppColors.mossSoft,
      child: Center(
        child: Icon(
          Icons.home_outlined,
          size: 48,
          color: AppColors.mossDeep.withValues(alpha: 0.7),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: asAspectRatio
            ? AspectRatio(aspectRatio: 16 / 9, child: child)
            : SizedBox(height: 160, width: double.infinity, child: child),
      ),
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

class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid({required this.stats});

  final HomeDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final valueFormat = NumberFormat.compactCurrency(
      symbol: '${stats.valueCurrency} ',
      decimalDigits: 0,
    );
    final cards = [
      _DashCard(label: 'Rooms', value: '${stats.roomsCount}'),
      _DashCard(label: 'Furniture', value: '${stats.baseFurnitureCount}'),
      _DashCard(label: 'Members', value: '${stats.membersCount}'),
      _DashCard(
        label: 'Est. value',
        value: valueFormat.format(stats.estimatedValue),
        caption: _valueCaption(stats),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: cards,
    );
  }

  String? _valueCaption(HomeDashboardStats stats) {
    final parts = <String>[];
    parts.add('In ${stats.valueCurrency}');
    if (stats.rateDate != null) {
      parts.add('FX ${DateFormat.yMMMd().format(stats.rateDate!.toLocal())}');
    }
    if (stats.ratesStale) parts.add('stale rates');
    if (stats.valueIsPartial && stats.unconvertedItemCount > 0) {
      parts.add('${stats.unconvertedItemCount} unconverted');
    }
    return parts.join(' · ');
  }
}

class _DashCard extends StatelessWidget {
  const _DashCard({
    required this.label,
    required this.value,
    this.caption,
  });

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mossSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (caption != null)
            Text(
              caption!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
            ),
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
