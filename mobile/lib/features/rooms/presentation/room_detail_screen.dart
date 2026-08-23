import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/web_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/inventory_node.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/entity_thumbnail.dart';
import '../../../shared/widgets/home_invite_sheet.dart';
import '../../../shared/widgets/home_shell_bottom_nav.dart';
import '../../../shared/widgets/user_menu_button.dart';
import '../../homes/presentation/homes_providers.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../trips/presentation/trips_providers.dart';
import 'rooms_providers.dart';

class RoomDetailScreen extends ConsumerStatefulWidget {
  const RoomDetailScreen({
    super.key,
    required this.homeId,
    required this.roomId,
    this.parentNodeId,
  });

  final String homeId;
  final String roomId;
  final String? parentNodeId;

  @override
  ConsumerState<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends ConsumerState<RoomDetailScreen> {
  String? _selectedId;

  String get homeId => widget.homeId;
  String get roomId => widget.roomId;
  String? get parentNodeId => widget.parentNodeId;

  @override
  void didUpdateWidget(covariant RoomDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parentNodeId != widget.parentNodeId ||
        oldWidget.roomId != widget.roomId) {
      _selectedId = null;
    }
  }

  Future<void> _addObject(InventoryScope scope, bool canEdit) async {
    if (!canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to add objects.'),
        ),
      );
      return;
    }
    await context.push(
      parentNodeId == null
          ? '/homes/$homeId/rooms/$roomId/nodes/new'
          : '/homes/$homeId/rooms/$roomId/nodes/new?parent=$parentNodeId',
    );
    ref.invalidate(inventoryChildrenProvider(scope));
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomProvider(roomId));
    final homeAsync = ref.watch(homeProvider(homeId));
    final scope = InventoryScope(
      homeId: homeId,
      roomId: roomId,
      parentNodeId: parentNodeId,
    );
    final childrenAsync = ref.watch(inventoryChildrenProvider(scope));
    final parentAsync = parentNodeId == null
        ? null
        : ref.watch(inventoryNodeProvider(parentNodeId!));
    final roomImagesAsync = parentNodeId == null
        ? ref.watch(roomImagesProvider((homeId: homeId, roomId: roomId)))
        : null;

    final canEdit = homeAsync.maybeWhen(
      data: (h) => h.myRole?.canEditInventory ?? false,
      orElse: () => false,
    );
    final canInvite = homeAsync.maybeWhen(
      data: (h) => h.myRole?.canManageMembers ?? false,
      orElse: () => false,
    );
    final desktop = isWebDesktopLayout(context);

    final title = parentAsync?.maybeWhen(
          data: (n) => n.name,
          orElse: () => null,
        ) ??
        roomAsync.maybeWhen(data: (r) => r.name, orElse: () => 'Room');

    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'Room'),
        actions: [
          if (canEdit && parentNodeId == null)
            IconButton(
              tooltip: 'Edit room',
              onPressed: () async {
                await context.push('/homes/$homeId/rooms/$roomId/edit');
                ref.invalidate(roomProvider(roomId));
                ref.invalidate(roomsListProvider(homeId));
                ref.invalidate(
                  roomImagesProvider((homeId: homeId, roomId: roomId)),
                );
              },
              icon: const Icon(Icons.edit_outlined),
            ),
          if (canEdit && parentNodeId != null)
            IconButton(
              tooltip: 'Edit',
              onPressed: () async {
                await context.push(
                  '/homes/$homeId/rooms/$roomId/nodes/$parentNodeId/edit',
                );
                ref.invalidate(inventoryNodeProvider(parentNodeId!));
                ref.invalidate(inventoryChildrenProvider(scope));
              },
              icon: const Icon(Icons.edit_outlined),
            ),
          if (parentNodeId != null)
            IconButton(
              tooltip: 'Details',
              onPressed: () => context.push(
                '/homes/$homeId/rooms/$roomId/nodes/$parentNodeId/details',
              ),
              icon: const Icon(Icons.info_outline),
            ),
          if (!desktop) const UserMenuButton(),
        ],
      ),
      floatingActionButton: desktop && canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _addObject(scope, canEdit),
              backgroundColor: AppColors.moss,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add object'),
            )
          : null,
      bottomNavigationBar: desktop
          ? null
          : HomeShellBottomNav(
              selectedIndex: 2,
              addLabel: 'Add object',
              onSelect: (index) async {
                switch (index) {
                  case 0:
                    await context.push('/homes/$homeId/search');
                  case 1:
                    await context.push('/homes/$homeId/trips');
                  case 2:
                    context.go('/homes/$homeId');
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
                    await _addObject(scope, canEdit);
                }
              },
            ),
      body: childrenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(inventoryChildrenProvider(scope)),
        ),
        data: (nodes) {
          final idsKey = nodes.map((n) => n.id).join(',');
          final thumbs = ref
              .watch(
                entityThumbnailsProvider(
                  (
                    homeId: homeId,
                    entityType: 'INVENTORY_NODE',
                    idsKey: idsKey,
                  ),
                ),
              )
              .maybeWhen(
                data: (m) => m,
                orElse: () => const <String, String>{},
              );
          final packedMap = ref
              .watch(homePackedNodesProvider(homeId))
              .maybeWhen(
                data: (m) => m,
                orElse: () => const <String, PackedNodeInfo>{},
              );

          final listPane = _InventoryListPane(
            homeId: homeId,
            roomId: roomId,
            parentNodeId: parentNodeId,
            scope: scope,
            nodes: nodes,
            thumbs: thumbs,
            packedMap: packedMap,
            canEdit: canEdit,
            roomImagesAsync: roomImagesAsync,
            selectedId: desktop ? _selectedId : null,
            desktop: desktop,
            onSelect: (node) {
              if (!desktop) {
                if (node.isContainer) {
                  context.push(
                    '/homes/$homeId/rooms/$roomId/nodes/${node.id}',
                  );
                } else {
                  context.push(
                    '/homes/$homeId/rooms/$roomId/nodes/${node.id}/details',
                  );
                }
                return;
              }
              setState(() => _selectedId = node.id);
            },
          );

          if (!desktop) return listPane;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 400,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(
                      right: BorderSide(color: AppColors.line),
                    ),
                  ),
                  child: listPane,
                ),
              ),
              Expanded(
                child: _DesktopDetailPane(
                  homeId: homeId,
                  roomId: roomId,
                  scope: scope,
                  selectedId: _selectedId,
                  canEdit: canEdit,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InventoryListPane extends ConsumerWidget {
  const _InventoryListPane({
    required this.homeId,
    required this.roomId,
    required this.parentNodeId,
    required this.scope,
    required this.nodes,
    required this.thumbs,
    required this.packedMap,
    required this.canEdit,
    required this.roomImagesAsync,
    required this.selectedId,
    required this.desktop,
    required this.onSelect,
  });

  final String homeId;
  final String roomId;
  final String? parentNodeId;
  final InventoryScope scope;
  final List<InventoryNode> nodes;
  final Map<String, String> thumbs;
  final Map<String, PackedNodeInfo> packedMap;
  final bool canEdit;
  final AsyncValue<List<EntityImage>>? roomImagesAsync;
  final String? selectedId;
  final bool desktop;
  final ValueChanged<InventoryNode> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(inventoryChildrenProvider(scope));
        ref.invalidate(homePackedNodesProvider(homeId));
        if (parentNodeId == null) {
          ref.invalidate(
            roomImagesProvider((homeId: homeId, roomId: roomId)),
          );
        }
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, desktop ? 32 : 100),
        children: [
          if (parentNodeId == null && roomImagesAsync != null)
            roomImagesAsync!.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (images) {
                if (images.isEmpty) return const SizedBox.shrink();
                final cover = images.first;
                if (cover.signedUrl == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        cover.signedUrl!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),
          if (nodes.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: EmptyState(
                icon: Icons.inventory_2_outlined,
                title: parentNodeId == null ? 'Empty room' : 'Empty container',
                message: canEdit
                    ? 'Add furniture, storage locations, or items. Items can also be containers.'
                    : 'Nothing stored here yet.',
              ),
            )
          else
            for (var i = 0; i < nodes.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              Builder(
                builder: (context) {
                  final node = nodes[i];
                  final packed = packedMap[node.id];
                  final selected = selectedId == node.id;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: selected
                          ? Border.all(color: AppColors.moss, width: 2)
                          : null,
                    ),
                    child: SoftTile(
                      leading: EntityThumbnail(
                        imageUrl: thumbs[node.id],
                        fallback: _nodeIcon(node),
                      ),
                      title: node.name,
                      subtitle: _subtitle(node, packed),
                      dimmed: packed != null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canEdit)
                            IconButton(
                              tooltip: 'Edit',
                              icon: const Icon(Icons.edit_outlined),
                              color: AppColors.inkMuted,
                              onPressed: () async {
                                await context.push(
                                  '/homes/$homeId/rooms/$roomId/nodes/${node.id}/edit',
                                );
                                ref.invalidate(
                                  inventoryChildrenProvider(scope),
                                );
                                ref.invalidate(
                                  inventoryNodeProvider(node.id),
                                );
                              },
                            ),
                          PopupMenuButton<String>(
                            tooltip: 'More',
                            onSelected: (value) async {
                              switch (value) {
                                case 'details':
                                  await context.push(
                                    '/homes/$homeId/rooms/$roomId/nodes/${node.id}/details',
                                  );
                                case 'open':
                                  await context.push(
                                    '/homes/$homeId/rooms/$roomId/nodes/${node.id}',
                                  );
                                case 'edit':
                                  await context.push(
                                    '/homes/$homeId/rooms/$roomId/nodes/${node.id}/edit',
                                  );
                                  ref.invalidate(
                                    inventoryChildrenProvider(scope),
                                  );
                                  ref.invalidate(
                                    inventoryNodeProvider(node.id),
                                  );
                              }
                            },
                            itemBuilder: (context) => [
                              if (canEdit)
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                              const PopupMenuItem(
                                value: 'details',
                                child: Text('Details'),
                              ),
                              if (node.isContainer)
                                const PopupMenuItem(
                                  value: 'open',
                                  child: Text('Open contents'),
                                ),
                            ],
                          ),
                        ],
                      ),
                      onTap: () => onSelect(node),
                    ),
                  );
                },
              ),
            ],
        ],
      ),
    );
  }
}

class _DesktopDetailPane extends ConsumerWidget {
  const _DesktopDetailPane({
    required this.homeId,
    required this.roomId,
    required this.scope,
    required this.selectedId,
    required this.canEdit,
  });

  final String homeId;
  final String roomId;
  final InventoryScope scope;
  final String? selectedId;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedId == null) {
      return const EmptyState(
        icon: Icons.view_sidebar_outlined,
        title: 'Select an item',
        message:
            'Pick something from the list to inspect it here. Containers can be opened in place.',
      );
    }

    final nodeAsync = ref.watch(inventoryNodeProvider(selectedId!));
    return nodeAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (node) {
        return Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(node.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                [
                  node.kindLabel,
                  if (node.itemCategory != null) node.itemCategory!.label,
                  if (node.isContainer) 'Container',
                  if (node.isMobileContainer) 'Mobile',
                ].join(' · '),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (node.description != null &&
                  node.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  node.description!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (node.isContainer)
                    FilledButton.icon(
                      onPressed: () => context.push(
                        '/homes/$homeId/rooms/$roomId/nodes/${node.id}',
                      ),
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Open contents'),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: () => context.push(
                      '/homes/$homeId/rooms/$roomId/nodes/${node.id}/details',
                    ),
                    icon: const Icon(Icons.info_outline),
                    label: const Text('Full details'),
                  ),
                  if (canEdit)
                    OutlinedButton.icon(
                      onPressed: () async {
                        await context.push(
                          '/homes/$homeId/rooms/$roomId/nodes/${node.id}/edit',
                        );
                        ref.invalidate(inventoryChildrenProvider(scope));
                        ref.invalidate(inventoryNodeProvider(node.id));
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                'Tip: turn an item into a container from Edit → “Also a container”.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

String _subtitle(InventoryNode node, PackedNodeInfo? packed) {
  final parts = <String>[node.kindLabel];
  if (node.itemCategory != null) parts.add(node.itemCategory!.label);
  if (node.quantity != null) {
    parts.add(
      [
        _formatQty(node.quantity!),
        if (node.quantityUnit != null) node.quantityUnit!,
      ].join(' '),
    );
  }
  if (node.purchasePrice != null) {
    parts.add(
      '${node.currency ?? ''} ${_formatQty(node.purchasePrice!)}'.trim(),
    );
  }
  if (packed != null) {
    parts.add(
      'Packed · ${packed.tripName}'
      '${packed.packedIntoName != null ? ' (${packed.packedIntoName})' : ''}',
    );
  }
  return parts.join(' · ');
}

String _formatQty(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}

IconData _nodeIcon(InventoryNode node) {
  return switch (node.nodeKind) {
    InventoryNodeKind.furniture => Icons.weekend_outlined,
    InventoryNodeKind.storageLocation => Icons.grid_view_outlined,
    InventoryNodeKind.item =>
      node.isContainer ? Icons.work_outline : Icons.inventory_2_outlined,
  };
}
