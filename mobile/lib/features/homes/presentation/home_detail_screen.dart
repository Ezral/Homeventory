import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/home.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/entity_thumbnail.dart';
import 'homes_providers.dart';
import '../../rooms/presentation/rooms_providers.dart';

class HomeDetailScreen extends ConsumerWidget {
  const HomeDetailScreen({super.key, required this.homeId});

  final String homeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeAsync = ref.watch(homeProvider(homeId));
    final roomsAsync = ref.watch(roomsListProvider(homeId));

    return homeAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(homeProvider(homeId)),
        ),
      ),
      data: (home) {
        final canEdit = home.myRole?.canEditInventory ?? false;
        final canInvite = home.myRole?.canManageMembers ?? false;

        return Scaffold(
          appBar: AppBar(
            title: Text(home.name),
            actions: [
              IconButton(
                tooltip: 'Search',
                onPressed: () => context.push('/homes/$homeId/search'),
                icon: const Icon(Icons.search),
              ),
              IconButton(
                tooltip: 'Trips',
                onPressed: () => context.push('/homes/$homeId/trips'),
                icon: const Icon(Icons.luggage_outlined),
              ),
              if (canInvite)
                IconButton(
                  tooltip: 'Invite',
                  onPressed: () => _showInviteSheet(context, ref),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                ),
            ],
          ),
          floatingActionButton: canEdit
              ? FloatingActionButton.extended(
                  onPressed: () => context.push('/homes/$homeId/rooms/new'),
                  backgroundColor: AppColors.moss,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('Add room'),
                )
              : null,
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(homeProvider(homeId));
              ref.invalidate(roomsListProvider(homeId));
              ref.invalidate(homeMembersProvider(homeId));
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
                        if (home.description != null &&
                            home.description!.isNotEmpty)
                          Text(
                            home.description!,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (home.myRole != null)
                              Chip(label: Text(home.myRole!.label)),
                            Chip(label: Text(home.defaultCurrency)),
                            if (home.addressText != null)
                              Chip(label: Text(home.addressText!)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const SectionLabel('Members'),
                        const SizedBox(height: 10),
                        _MembersSection(
                          homeId: homeId,
                          canManage: canInvite,
                          myRole: home.myRole,
                        ),
                        const SizedBox(height: 20),
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
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showInviteSheet(BuildContext context, WidgetRef ref) async {
    HomeRole role = HomeRole.editor;
    var busy = false;
    String? token;
    String? shortCode;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Invite someone',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Creates a single-use invite. Only the token hash is stored on the server.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<HomeRole>(
                    // ignore: deprecated_member_use
                    value: role,
                    items: HomeRole.values
                        .where((r) => r != HomeRole.owner)
                        .map(
                          (r) =>
                              DropdownMenuItem(value: r, child: Text(r.label)),
                        )
                        .toList(),
                    onChanged: token != null
                        ? null
                        : (v) {
                            if (v != null) setModalState(() => role = v);
                          },
                    decoration: const InputDecoration(labelText: 'Role'),
                  ),
                  const SizedBox(height: 16),
                  if (token == null)
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              setModalState(() => busy = true);
                              try {
                                final invite = await ref
                                    .read(homesRepositoryProvider)
                                    .createInvitation(
                                      homeId: homeId,
                                      role: role,
                                    );
                                setModalState(() {
                                  token = invite.token;
                                  shortCode = invite.shortCode;
                                });
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                }
                              } finally {
                                setModalState(() => busy = false);
                              }
                            },
                      child: Text(busy ? 'Creating…' : 'Create invite'),
                    )
                  else ...[
                    SelectableText(
                      'Short code: $shortCode',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(token!),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final value = shortCode ?? token!;
                        await Clipboard.setData(ClipboardData(text: value));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                shortCode != null
                                    ? 'Short code copied'
                                    : 'Invite token copied',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy),
                      label: Text(
                        shortCode != null ? 'Copy short code' : 'Copy token',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: token!));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Full invite token copied'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.link),
                      label: const Text('Copy full token'),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MembersSection extends ConsumerWidget {
  const _MembersSection({
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
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(homeMembersProvider(homeId)),
      ),
      data: (members) {
        if (members.isEmpty) {
          return Text(
            'No active members.',
            style: Theme.of(context).textTheme.bodyMedium,
          );
        }
        return Column(
          children: [
            for (final member in members)
              SoftTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.mossSoft,
                  child: Text(
                    member.label.isNotEmpty
                        ? member.label.substring(0, 1).toUpperCase()
                        : '?',
                    style: const TextStyle(color: AppColors.mossDeep),
                  ),
                ),
                title: member.label,
                subtitle: member.role.label,
                trailing: canManage && member.role != HomeRole.owner
                    ? IconButton(
                        tooltip: 'Remove member',
                        icon: const Icon(Icons.person_remove_outlined),
                        onPressed: () => _confirmRemove(context, ref, member),
                      )
                    : const SizedBox.shrink(),
              ),
            if (myRole != null && myRole != HomeRole.owner) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _confirmLeave(context, ref),
                  child: const Text('Leave home'),
                ),
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
      if (context.mounted) context.go('/homes');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}
