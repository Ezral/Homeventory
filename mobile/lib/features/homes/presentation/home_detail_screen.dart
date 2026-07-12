import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/app_widgets.dart';
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
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
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
                      onRetry: () =>
                          ref.invalidate(roomsListProvider(homeId)),
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
                              ? () =>
                                  context.push('/homes/$homeId/rooms/new')
                              : null,
                        ),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      sliver: SliverList.separated(
                        itemCount: rooms.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final room = rooms[index];
                          return SoftTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.mossSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.meeting_room_outlined,
                                color: AppColors.mossDeep,
                              ),
                            ),
                            title: room.name,
                            subtitle: room.description,
                            onTap: () => context.push(
                              '/homes/$homeId/rooms/${room.id}',
                            ),
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
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(r.label),
                          ),
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
                        await Clipboard.setData(ClipboardData(text: token!));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Invite token copied'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy token'),
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
