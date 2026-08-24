import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/web_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/inventory_node.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/inventory_row_card.dart';
import '../../../shared/widgets/home_invite_sheet.dart';
import '../../../shared/widgets/home_shell_bottom_nav.dart';
import '../../../shared/widgets/user_menu_button.dart';
import '../../../shared/utils/inventory_labels.dart';
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
          final locationPaths = ref
              .watch(nodeLocationPathsProvider(idsKey))
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
            locationPaths: locationPaths,
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
              Expanded(
                flex: 4,
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
                flex: 5,
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
    required this.locationPaths,
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
  final Map<String, String> locationPaths;
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
                      aspectRatio: desktop ? 2.4 : 2.0,
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
                  return InventoryRowCard(
                    imageUrl: thumbs[node.id],
                    fallbackIcon: _nodeIcon(node),
                    title: node.name,
                    subtitle: inventoryNodeSubtitle(
                      node,
                      locationPath: locationPaths[node.id],
                      packed: packed,
                    ),
                    dimmed: packed != null,
                    selected: selected,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canEdit)
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_outlined),
                            color: AppColors.inkMuted,
                            visualDensity: VisualDensity.compact,
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
                  );
                },
              ),
            ],
        ],
      ),
    );
  }
}

class _DesktopDetailPane extends ConsumerStatefulWidget {
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
  ConsumerState<_DesktopDetailPane> createState() => _DesktopDetailPaneState();
}

class _DesktopDetailPaneState extends ConsumerState<_DesktopDetailPane> {
  /// When set, show this item's details while a container stays selected.
  String? _nestedItemId;

  @override
  void didUpdateWidget(covariant _DesktopDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId) {
      _nestedItemId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedId == null) {
      return const EmptyState(
        icon: Icons.view_sidebar_outlined,
        title: 'Select an object',
        message:
            'Pick something from the list. Containers show their contents here; '
            'items open their details here.',
      );
    }

    final focusId = _nestedItemId ?? widget.selectedId!;
    final nodeAsync = ref.watch(inventoryNodeProvider(focusId));

    return nodeAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (node) {
        final showingNestedItem = _nestedItemId != null;
        final showContents = node.isContainer && !showingNestedItem;

        if (showContents) {
          return _DesktopContainerContents(
            homeId: widget.homeId,
            roomId: widget.roomId,
            container: node,
            canEdit: widget.canEdit,
            listScope: widget.scope,
            onOpenItem: (item) => setState(() => _nestedItemId = item.id),
            onOpenNestedContainer: (child) {
              context.push(
                '/homes/${widget.homeId}/rooms/${widget.roomId}/nodes/${child.id}',
              );
            },
          );
        }

        return _DesktopItemDetails(
          homeId: widget.homeId,
          roomId: widget.roomId,
          node: node,
          canEdit: widget.canEdit,
          listScope: widget.scope,
          onBack: showingNestedItem
              ? () => setState(() => _nestedItemId = null)
              : null,
        );
      },
    );
  }
}

class _DesktopContainerContents extends ConsumerWidget {
  const _DesktopContainerContents({
    required this.homeId,
    required this.roomId,
    required this.container,
    required this.canEdit,
    required this.listScope,
    required this.onOpenItem,
    required this.onOpenNestedContainer,
  });

  final String homeId;
  final String roomId;
  final InventoryNode container;
  final bool canEdit;
  final InventoryScope listScope;
  final ValueChanged<InventoryNode> onOpenItem;
  final ValueChanged<InventoryNode> onOpenNestedContainer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childScope = InventoryScope(
      homeId: homeId,
      roomId: roomId,
      parentNodeId: container.id,
    );
    final childrenAsync = ref.watch(inventoryChildrenProvider(childScope));
    final packedMap = ref.watch(homePackedNodesProvider(homeId)).maybeWhen(
          data: (m) => m,
          orElse: () => const <String, PackedNodeInfo>{},
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      container.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        container.kindLabel,
                        'Contents',
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (canEdit)
                IconButton(
                  tooltip: 'Edit',
                  onPressed: () async {
                    await context.push(
                      '/homes/$homeId/rooms/$roomId/nodes/${container.id}/edit',
                    );
                    ref.invalidate(inventoryNodeProvider(container.id));
                    ref.invalidate(inventoryChildrenProvider(listScope));
                    ref.invalidate(inventoryChildrenProvider(childScope));
                  },
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.line),
        Expanded(
          child: childrenAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(
              message: e.toString(),
              onRetry: () =>
                  ref.invalidate(inventoryChildrenProvider(childScope)),
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

              final locationPaths = ref
                  .watch(nodeLocationPathsProvider(idsKey))
                  .maybeWhen(
                    data: (m) => m,
                    orElse: () => const <String, String>{},
                  );

              if (nodes.isEmpty) {
                return EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Empty container',
                  message: canEdit
                      ? 'Add objects inside ${container.name}.'
                      : 'Nothing stored here yet.',
                  actionLabel: canEdit ? 'Add object' : null,
                  onAction: canEdit
                      ? () async {
                          await context.push(
                            '/homes/$homeId/rooms/$roomId/nodes/new?parent=${container.id}',
                          );
                          ref.invalidate(
                            inventoryChildrenProvider(childScope),
                          );
                        }
                      : null,
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                itemCount: nodes.length + (canEdit ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (canEdit && index == nodes.length) {
                    return OutlinedButton.icon(
                      onPressed: () async {
                        await context.push(
                          '/homes/$homeId/rooms/$roomId/nodes/new?parent=${container.id}',
                        );
                        ref.invalidate(inventoryChildrenProvider(childScope));
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add object inside'),
                    );
                  }
                  final node = nodes[index];
                  final packed = packedMap[node.id];
                  return InventoryRowCard(
                    imageUrl: thumbs[node.id],
                    fallbackIcon: _nodeIcon(node),
                    title: node.name,
                    subtitle: inventoryNodeSubtitle(
                      node,
                      locationPath: locationPaths[node.id],
                      packed: packed,
                    ),
                    dimmed: packed != null,
                    trailing: Padding(
                      padding: const EdgeInsets.only(right: 8, top: 4),
                      child: Icon(
                        node.isContainer
                            ? Icons.chevron_right
                            : Icons.info_outline,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    onTap: () {
                      if (node.isContainer) {
                        onOpenNestedContainer(node);
                      } else {
                        onOpenItem(node);
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DesktopItemDetails extends ConsumerWidget {
  const _DesktopItemDetails({
    required this.homeId,
    required this.roomId,
    required this.node,
    required this.canEdit,
    required this.listScope,
    this.onBack,
  });

  final String homeId;
  final String roomId;
  final InventoryNode node;
  final bool canEdit;
  final InventoryScope listScope;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imagesAsync = ref.watch(
      nodeImagesProvider((homeId: homeId, nodeId: node.id)),
    );
    final barcodesAsync = ref.watch(nodeBarcodesProvider(node.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onBack != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back to contents'),
              ),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      node.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  if (canEdit)
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () async {
                        await context.push(
                          '/homes/$homeId/rooms/$roomId/nodes/${node.id}/edit',
                        );
                        ref.invalidate(inventoryNodeProvider(node.id));
                        ref.invalidate(inventoryChildrenProvider(listScope));
                      },
                      icon: const Icon(Icons.edit_outlined),
                    ),
                ],
              ),
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
              const SizedBox(height: 8),
              ref.watch(nodeLocationPathProvider(node.id)).when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (path) {
                      if (path == null || path.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        path,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.inkMuted,
                            ),
                      );
                    },
                  ),
              if (node.description != null &&
                  node.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  node.description!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 20),
              const SectionLabel('Photos'),
              const SizedBox(height: 8),
              imagesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(e.toString()),
                data: (images) {
                  if (images.isEmpty) {
                    return Text(
                      'No photos yet.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    );
                  }
                  return SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final image = images[index];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: image.signedUrl == null
                              ? Container(
                                  width: 120,
                                  height: 120,
                                  color: AppColors.mossSoft,
                                  child: const Icon(Icons.broken_image),
                                )
                              : Image.network(
                                  image.signedUrl!,
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                ),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              const SectionLabel('Details'),
              const SizedBox(height: 10),
              ref.watch(nodeLocationPathProvider(node.id)).when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (path) {
                      if (path == null || path.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return _PaneDetailRow(label: 'Location', value: path);
                    },
                  ),
              _PaneDetailRow(
                label: 'Quantity',
                value: node.quantity == null
                    ? '—'
                    : [
                        _formatQty(node.quantity!),
                        if (node.quantityUnit != null) node.quantityUnit!,
                      ].join(' '),
              ),
              _PaneDetailRow(
                label: 'Brand',
                value: node.brand ?? '—',
              ),
              _PaneDetailRow(
                label: 'Purchase price',
                value: node.purchasePrice == null
                    ? '—'
                    : '${node.currency ?? ''} ${_formatQty(node.purchasePrice!)}'
                        .trim(),
              ),
              _PaneDetailRow(
                label: 'Weight',
                value: node.weight == null
                    ? '—'
                    : [
                        _formatQty(node.weight!),
                        if (node.weightUnit != null) node.weightUnit!,
                      ].join(' '),
              ),
              const SizedBox(height: 20),
              const SectionLabel('Barcodes'),
              const SizedBox(height: 8),
              barcodesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Text(e.toString()),
                data: (codes) {
                  if (codes.isEmpty) {
                    return Text(
                      'No barcodes.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final code in codes)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            code.barcodeValue,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (canEdit)
                    OutlinedButton.icon(
                      onPressed: () async {
                        await context.push(
                          '/homes/$homeId/rooms/$roomId/nodes/${node.id}/edit',
                        );
                        ref.invalidate(inventoryNodeProvider(node.id));
                        ref.invalidate(inventoryChildrenProvider(listScope));
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                  if (canEdit)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final moved = await context.push<bool>(
                          '/homes/$homeId/rooms/$roomId/nodes/${node.id}/move',
                        );
                        if (moved == true) {
                          ref.invalidate(inventoryNodeProvider(node.id));
                          ref.invalidate(inventoryChildrenProvider(listScope));
                        }
                      },
                      icon: const Icon(Icons.drive_file_move_outlined),
                      label: const Text('Move'),
                    ),
                  TextButton(
                    onPressed: () => context.push(
                      '/homes/$homeId/rooms/$roomId/nodes/${node.id}/details',
                    ),
                    child: const Text('Open full page'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaneDetailRow extends StatelessWidget {
  const _PaneDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
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
