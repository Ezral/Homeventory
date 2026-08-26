import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/web_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/bulk_node_draft.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/inventory_node.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/bulk_add_dialog.dart';
import '../../../shared/widgets/bulk_edit_dialog.dart';
import '../../../shared/widgets/bulk_pack_sheet.dart';
import '../../../shared/widgets/entity_photo_gallery.dart';
import '../../../shared/widgets/image_ingest_region.dart';
import '../../../shared/widgets/home_shell_bottom_nav.dart';
import '../../../shared/widgets/inventory_row_card.dart';
import '../../../shared/widgets/selection_action_bar.dart';
import '../../../shared/widgets/user_menu_button.dart';
import '../../../shared/utils/image_pick.dart';
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
  final Map<String, InventoryNode> _bulkSelected = {};

  /// Desktop: container whose contents occupy the detail pane (furniture or
  /// nested storage). Null means add at the left-list level.
  String? _desktopViewedContainerId;

  String get homeId => widget.homeId;
  String get roomId => widget.roomId;
  String? get parentNodeId => widget.parentNodeId;
  String? get _addParentId => _desktopViewedContainerId ?? parentNodeId;

  @override
  void didUpdateWidget(covariant RoomDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parentNodeId != widget.parentNodeId ||
        oldWidget.roomId != widget.roomId) {
      _selectedId = null;
      _bulkSelected.clear();
      _desktopViewedContainerId = null;
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
      _addParentId == null
          ? '/homes/$homeId/rooms/$roomId/nodes/new'
          : '/homes/$homeId/rooms/$roomId/nodes/new?parent=$_addParentId',
    );
    ref.invalidate(inventoryChildrenProvider(scope));
    _invalidateAddParentChildren();
  }

  void _invalidateAddParentChildren() {
    if (_addParentId == null || _addParentId == parentNodeId) return;
    ref.invalidate(
      inventoryChildrenProvider(
        InventoryScope(
          homeId: homeId,
          roomId: roomId,
          parentNodeId: _addParentId,
        ),
      ),
    );
  }

  void _toggleBulk(InventoryNode node) {
    setState(() {
      if (_bulkSelected.containsKey(node.id)) {
        _bulkSelected.remove(node.id);
      } else {
        _bulkSelected[node.id] = node;
      }
    });
  }

  Future<void> _addSeveral(InventoryScope scope) async {
    final count = await showBulkAddItemsSheet(
      context: context,
      homeId: homeId,
      roomId: roomId,
      parentNodeId: _addParentId,
    );
    if (count == null || count <= 0) return;
    ref.invalidate(inventoryChildrenProvider(scope));
    _invalidateAddParentChildren();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added $count ${count == 1 ? 'entry' : 'entries'}'),
      ),
    );
  }

  Future<void> _bulkEdit() async {
    final selected = _bulkSelected.values.toList();
    if (selected.isEmpty) return;
    final count = await showBulkEditSheet(
      context: context,
      homeId: homeId,
      nodes: selected,
    );
    if (count == null || count <= 0) return;
    ref.invalidate(
      inventoryChildrenProvider(
        InventoryScope(
          homeId: homeId,
          roomId: roomId,
          parentNodeId: parentNodeId,
        ),
      ),
    );
    for (final node in selected) {
      ref.invalidate(inventoryNodeProvider(node.id));
    }
    setState(_bulkSelected.clear);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Updated $count ${count == 1 ? 'entry' : 'entries'}'),
      ),
    );
  }

  Future<void> _bulkMove() async {
    final selected = _bulkSelected.values.toList();
    if (selected.isEmpty) return;
    final first = selected.first;
    final moved = await context.push<bool>(
      '/homes/$homeId/rooms/${first.roomId}/nodes/${first.id}/move',
      extra: selected.map((n) => n.id).toList(),
    );
    if (moved == true) {
      ref.invalidate(
        inventoryChildrenProvider(
          InventoryScope(
            homeId: homeId,
            roomId: roomId,
            parentNodeId: parentNodeId,
          ),
        ),
      );
      setState(_bulkSelected.clear);
    }
  }

  Future<void> _bulkDispose() async {
    final selected = _bulkSelected.values.toList();
    if (selected.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Dispose ${selected.length} item${selected.length == 1 ? '' : 's'}?',
        ),
        content: const Text(
          'Disposed items are hidden from inventory lists and search.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dispose'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final count = await ref
          .read(inventoryRepositoryProvider)
          .disposeNodes(selected.map((n) => n.id).toList());
      ref.invalidate(
        inventoryChildrenProvider(
          InventoryScope(
            homeId: homeId,
            roomId: roomId,
            parentNodeId: parentNodeId,
          ),
        ),
      );
      setState(_bulkSelected.clear);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Disposed $count')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _bulkPack() async {
    final selected = _bulkSelected.values.toList();
    if (selected.isEmpty) return;
    final count = await showBulkPackSheet(
      context: context,
      ref: ref,
      homeId: homeId,
      nodes: selected,
    );
    if (count == null) return;
    ref.invalidate(homePackedNodesProvider(homeId));
    setState(_bulkSelected.clear);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 0
              ? 'Nothing added — items may already be packed.'
              : 'Added $count to the packing plan',
        ),
      ),
    );
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
    final desktop = isWebDesktopLayout(context);

    final title =
        parentAsync?.maybeWhen(data: (n) => n.name, orElse: () => null) ??
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
          if (canEdit)
            IconButton(
              tooltip: 'Add several items',
              onPressed: () => _addSeveral(scope),
              icon: const Icon(Icons.playlist_add),
            ),
          if (!desktop) const UserMenuButton(),
        ],
      ),
      floatingActionButton: desktop && canEdit && _bulkSelected.isEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _addObject(scope, canEdit),
              backgroundColor: AppColors.moss,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add object'),
            )
          : null,
      bottomNavigationBar: _bulkSelected.isNotEmpty
          ? SelectionActionBar(
              count: _bulkSelected.length,
              onClear: () => setState(_bulkSelected.clear),
              onEdit: _bulkEdit,
              onMove: _bulkMove,
              onDispose: _bulkDispose,
              onPack: _bulkPack,
            )
          : desktop
          ? null
          : HomeShellBottomNav(
              selectedIndex: HomeShellNav.home,
              addLabel: 'Add object',
              onSelect: (index) => handleHomeShellSelect(
                context: context,
                homeId: homeId,
                index: index,
                canEdit: canEdit,
                addDeniedMessage: 'You do not have permission to add objects.',
                onAdd: () => _addObject(scope, canEdit),
              ),
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
                entityThumbnailsProvider((
                  homeId: homeId,
                  entityType: 'INVENTORY_NODE',
                  idsKey: idsKey,
                )),
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
            bulkSelected: _bulkSelected,
            onToggleBulk: _toggleBulk,
            onSelect: (node) {
              if (!desktop) {
                if (node.isContainer) {
                  context.push('/homes/$homeId/rooms/$roomId/nodes/${node.id}');
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
                    border: Border(right: BorderSide(color: AppColors.line)),
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
                  bulkSelected: _bulkSelected,
                  onToggleBulk: _toggleBulk,
                  onViewedAddParentChanged: (id) {
                    if (_desktopViewedContainerId == id) return;
                    setState(() => _desktopViewedContainerId = id);
                  },
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
    required this.bulkSelected,
    required this.onToggleBulk,
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
  final Map<String, InventoryNode> bulkSelected;
  final ValueChanged<InventoryNode> onToggleBulk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(inventoryChildrenProvider(scope));
        ref.invalidate(homePackedNodesProvider(homeId));
        if (parentNodeId == null) {
          ref.invalidate(roomImagesProvider((homeId: homeId, roomId: roomId)));
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
                      child: Image.network(cover.signedUrl!, fit: BoxFit.cover),
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
                    fallbackIcon: inventoryNodeIcon(node),
                    title: node.name,
                    subtitle: inventoryNodeSubtitle(
                      node,
                      locationPath: locationPaths[node.id],
                      packed: packed,
                    ),
                    dimmed: packed != null,
                    selected: selected || bulkSelected.containsKey(node.id),
                    showCheckbox:
                        canEdit && (desktop || bulkSelected.isNotEmpty),
                    checked: bulkSelected.containsKey(node.id),
                    onToggleChecked: canEdit ? () => onToggleBulk(node) : null,
                    onLongPress: canEdit ? () => onToggleBulk(node) : null,
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
                              ref.invalidate(inventoryChildrenProvider(scope));
                              ref.invalidate(inventoryNodeProvider(node.id));
                            },
                          ),
                        PopupMenuButton<String>(
                          tooltip: 'More',
                          onSelected: (value) async {
                            switch (value) {
                              case 'select':
                                onToggleBulk(node);
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
                                ref.invalidate(inventoryNodeProvider(node.id));
                            }
                          },
                          itemBuilder: (context) => [
                            if (canEdit)
                              const PopupMenuItem(
                                value: 'select',
                                child: Text('Select'),
                              ),
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
                    onTap: () {
                      if (bulkSelected.isNotEmpty) {
                        onToggleBulk(node);
                        return;
                      }
                      onSelect(node);
                    },
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
    required this.bulkSelected,
    required this.onToggleBulk,
    required this.onViewedAddParentChanged,
  });

  final String homeId;
  final String roomId;
  final InventoryScope scope;
  final String? selectedId;
  final bool canEdit;
  final Map<String, InventoryNode> bulkSelected;
  final ValueChanged<InventoryNode> onToggleBulk;
  final ValueChanged<String?> onViewedAddParentChanged;

  @override
  ConsumerState<_DesktopDetailPane> createState() => _DesktopDetailPaneState();
}

class _DesktopDetailPaneState extends ConsumerState<_DesktopDetailPane> {
  /// Nested containers opened under [selectedId] (furniture → storage → …).
  final List<String> _containerPath = [];

  /// Item details opened inside the rightmost container pane.
  String? _nestedItemId;

  @override
  void didUpdateWidget(covariant _DesktopDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId) {
      _containerPath.clear();
      _nestedItemId = null;
    }
    if (oldWidget.selectedId != widget.selectedId ||
        oldWidget.scope != widget.scope) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _emitAddParent());
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _emitAddParent());
  }

  bool _selectedIsContainer() {
    final id = widget.selectedId;
    if (id == null) return false;
    return ref
        .read(inventoryNodeProvider(id))
        .maybeWhen(data: (node) => node.isContainer, orElse: () => false);
  }

  void _emitAddParent() {
    if (!mounted) return;
    widget.onViewedAddParentChanged(
      bulkAddParentId(
        listParentNodeId: widget.scope.parentNodeId,
        selectedId: widget.selectedId,
        selectedIsContainer: _selectedIsContainer(),
        nestedContainerPath: List<String>.from(_containerPath),
        nestedItemId: _nestedItemId,
      ),
    );
  }

  void _openNestedContainer(InventoryNode child) {
    setState(() {
      _nestedItemId = null;
      _containerPath.add(child.id);
    });
    _emitAddParent();
  }

  void _openItem(InventoryNode item) {
    setState(() => _nestedItemId = item.id);
    _emitAddParent();
  }

  void _popDrill() {
    setState(() {
      _nestedItemId = null;
      if (_containerPath.isNotEmpty) {
        _containerPath.removeLast();
      }
    });
    _emitAddParent();
  }

  void _backFromItem() {
    setState(() => _nestedItemId = null);
    _emitAddParent();
  }

  /// Id whose contents/details occupy the middle column (null = single pane).
  String? get _middleContainerId {
    if (_containerPath.isEmpty) return null;
    if (_containerPath.length == 1) return widget.selectedId;
    return _containerPath[_containerPath.length - 2];
  }

  /// Id for the rightmost column's container (before optional item details).
  String get _rightContainerId {
    if (_containerPath.isEmpty) return widget.selectedId!;
    return _containerPath.last;
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = widget.selectedId;
    if (selectedId != null) {
      ref.listen(inventoryNodeProvider(selectedId), (prev, next) {
        next.whenData((_) => _emitAddParent());
      });
    }

    if (selectedId == null) {
      return const EmptyState(
        icon: Icons.view_sidebar_outlined,
        title: 'Select an object',
        message:
            'Pick something from the list. Containers show their contents here; '
            'items open their details here.',
      );
    }

    final middleId = _middleContainerId;
    final showMiddle = middleId != null;

    final right = _nestedItemId != null
        ? _DesktopPaneNode(
            key: ValueKey('item-$_nestedItemId'),
            homeId: widget.homeId,
            roomId: widget.roomId,
            nodeId: _nestedItemId!,
            canEdit: widget.canEdit,
            bulkSelected: widget.bulkSelected,
            onToggleBulk: widget.onToggleBulk,
            listScope: widget.scope,
            forceItemDetails: true,
            onBack: _backFromItem,
            onBackLabel: 'Back to contents',
            onOpenItem: _openItem,
            onOpenNestedContainer: _openNestedContainer,
          )
        : _DesktopPaneNode(
            key: ValueKey('right-$_rightContainerId'),
            homeId: widget.homeId,
            roomId: widget.roomId,
            nodeId: _rightContainerId,
            canEdit: widget.canEdit,
            bulkSelected: widget.bulkSelected,
            onToggleBulk: widget.onToggleBulk,
            listScope: widget.scope,
            onBack: showMiddle ? _popDrill : null,
            onBackLabel: 'Back',
            onOpenItem: _openItem,
            onOpenNestedContainer: _openNestedContainer,
          );

    final middle = middleId == null
        ? null
        : _DesktopPaneNode(
            key: ValueKey('middle-$middleId'),
            homeId: widget.homeId,
            roomId: widget.roomId,
            nodeId: middleId,
            canEdit: widget.canEdit,
            bulkSelected: widget.bulkSelected,
            onToggleBulk: widget.onToggleBulk,
            listScope: widget.scope,
            onOpenItem: _openItem,
            onOpenNestedContainer: _openNestedContainer,
          );

    return _CascadingDetailColumns(
      showMiddle: showMiddle,
      middle: middle,
      right: right,
    );
  }
}

/// Side-by-side detail columns with a slide when the middle pane appears/leaves.
///
/// Technical pattern: column / Miller-column drill-down (push right, shift left).
class _CascadingDetailColumns extends StatefulWidget {
  const _CascadingDetailColumns({
    required this.showMiddle,
    required this.middle,
    required this.right,
  });

  final bool showMiddle;
  final Widget? middle;
  final Widget right;

  @override
  State<_CascadingDetailColumns> createState() =>
      _CascadingDetailColumnsState();
}

class _CascadingDetailColumnsState extends State<_CascadingDetailColumns>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t;
  Widget? _heldMiddle;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _t = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    if (widget.showMiddle && widget.middle != null) {
      _heldMiddle = widget.middle;
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant _CascadingDetailColumns oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showMiddle && widget.middle != null) {
      _heldMiddle = widget.middle;
      if (_controller.status != AnimationStatus.completed &&
          _controller.status != AnimationStatus.forward) {
        _controller.forward();
      }
    } else if (!widget.showMiddle && oldWidget.showMiddle) {
      _controller.reverse().whenComplete(() {
        if (!mounted) return;
        if (!widget.showMiddle) {
          setState(() => _heldMiddle = null);
        }
      });
    } else if (widget.middle != null) {
      _heldMiddle = widget.middle;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final t = _t.value;
        final middle = _heldMiddle;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (middle != null && t > 0.001)
              Expanded(
                flex: (420 * t).round().clamp(1, 420),
                child: Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(-28 * (1 - t), 0),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: AppColors.line),
                        ),
                      ),
                      child: middle,
                    ),
                  ),
                ),
              ),
            Expanded(
              flex: 500,
              child: Transform.translate(
                offset: Offset(36 * (1 - t) * (middle != null ? 1 : 0), 0),
                child: widget.right,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Loads a node and shows either its contents (container) or item details.
class _DesktopPaneNode extends ConsumerWidget {
  const _DesktopPaneNode({
    super.key,
    required this.homeId,
    required this.roomId,
    required this.nodeId,
    required this.canEdit,
    required this.listScope,
    required this.onOpenItem,
    required this.onOpenNestedContainer,
    required this.bulkSelected,
    required this.onToggleBulk,
    this.forceItemDetails = false,
    this.onBack,
    this.onBackLabel,
  });

  final String homeId;
  final String roomId;
  final String nodeId;
  final bool canEdit;
  final InventoryScope listScope;
  final ValueChanged<InventoryNode> onOpenItem;
  final ValueChanged<InventoryNode> onOpenNestedContainer;
  final Map<String, InventoryNode> bulkSelected;
  final ValueChanged<InventoryNode> onToggleBulk;
  final bool forceItemDetails;
  final VoidCallback? onBack;
  final String? onBackLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodeAsync = ref.watch(inventoryNodeProvider(nodeId));
    return nodeAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (node) {
        if (forceItemDetails || !node.isContainer) {
          return _DesktopItemDetails(
            homeId: homeId,
            roomId: roomId,
            node: node,
            canEdit: canEdit,
            listScope: listScope,
            onBack: onBack,
            onBackLabel: onBackLabel,
          );
        }
        return _DesktopContainerContents(
          homeId: homeId,
          roomId: roomId,
          container: node,
          canEdit: canEdit,
          listScope: listScope,
          onOpenItem: onOpenItem,
          onOpenNestedContainer: onOpenNestedContainer,
          bulkSelected: bulkSelected,
          onToggleBulk: onToggleBulk,
          onBack: onBack,
          onBackLabel: onBackLabel,
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
    required this.bulkSelected,
    required this.onToggleBulk,
    this.onBack,
    this.onBackLabel,
  });

  final String homeId;
  final String roomId;
  final InventoryNode container;
  final bool canEdit;
  final InventoryScope listScope;
  final ValueChanged<InventoryNode> onOpenItem;
  final ValueChanged<InventoryNode> onOpenNestedContainer;
  final Map<String, InventoryNode> bulkSelected;
  final ValueChanged<InventoryNode> onToggleBulk;
  final VoidCallback? onBack;
  final String? onBackLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childScope = InventoryScope(
      homeId: homeId,
      roomId: roomId,
      parentNodeId: container.id,
    );
    final childrenAsync = ref.watch(inventoryChildrenProvider(childScope));
    final packedMap = ref
        .watch(homePackedNodesProvider(homeId))
        .maybeWhen(
          data: (m) => m,
          orElse: () => const <String, PackedNodeInfo>{},
        );

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
                label: Text(onBackLabel ?? 'Back'),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, onBack != null ? 8 : 20, 16, 8),
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
                      [container.kindLabel, 'Contents'].join(' · '),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (canEdit)
                IconButton(
                  tooltip: 'Add several items',
                  onPressed: () async {
                    final count = await showBulkAddItemsSheet(
                      context: context,
                      homeId: homeId,
                      roomId: roomId,
                      parentNodeId: container.id,
                    );
                    if (count == null || count <= 0) return;
                    ref.invalidate(inventoryChildrenProvider(childScope));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Added $count ${count == 1 ? 'entry' : 'entries'}',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.playlist_add),
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
                    entityThumbnailsProvider((
                      homeId: homeId,
                      entityType: 'INVENTORY_NODE',
                      idsKey: idsKey,
                    )),
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
                          ref.invalidate(inventoryChildrenProvider(childScope));
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
                    fallbackIcon: inventoryNodeIcon(node),
                    title: node.name,
                    subtitle: inventoryNodeSubtitle(
                      node,
                      locationPath: locationPaths[node.id],
                      packed: packed,
                    ),
                    dimmed: packed != null,
                    selected: bulkSelected.containsKey(node.id),
                    showCheckbox: canEdit,
                    checked: bulkSelected.containsKey(node.id),
                    onToggleChecked: canEdit ? () => onToggleBulk(node) : null,
                    onLongPress: canEdit ? () => onToggleBulk(node) : null,
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
                      if (bulkSelected.isNotEmpty) {
                        onToggleBulk(node);
                        return;
                      }
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
    this.onBackLabel,
  });

  final String homeId;
  final String roomId;
  final InventoryNode node;
  final bool canEdit;
  final InventoryScope listScope;
  final VoidCallback? onBack;
  final String? onBackLabel;

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
                label: Text(onBackLabel ?? 'Back to contents'),
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
                  if (node.itemCategory != null &&
                      node.itemCategory != ItemCategory.clothing)
                    node.itemCategory!.label,
                  if (node.isContainer) 'Container',
                  if (node.isMobileContainer) 'Mobile',
                ].join(' · '),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              ref
                  .watch(nodeLocationPathProvider(node.id))
                  .when(
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
              ImageIngestRegion(
                enabled: canEdit,
                showHint: true,
                onImages: (images) => _addPhotos(context, ref, images),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: SectionLabel('Photos')),
                        if (canEdit)
                          TextButton.icon(
                            onPressed: () => _addPhoto(context, ref),
                            icon: const Icon(Icons.add_a_photo_outlined),
                            label: const Text('Add'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    imagesAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Text(e.toString()),
                      data: (images) {
                        return EntityPhotoGallery(
                          images: [
                            for (final image in images)
                              GalleryPhoto(id: image.id, url: image.signedUrl),
                          ],
                          canEdit: canEdit,
                          onDelete: canEdit
                              ? (id) => _deletePhoto(
                                  context,
                                  ref,
                                  images.firstWhere((image) => image.id == id),
                                )
                              : null,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionLabel('Details'),
              const SizedBox(height: 10),
              ref
                  .watch(nodeLocationPathProvider(node.id))
                  .when(
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
              _PaneDetailRow(label: 'Brand', value: node.brand ?? '—'),
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

  Future<void> _addPhoto(BuildContext context, WidgetRef ref) async {
    final picked = await pickEntityImage(context);
    if (picked == null || !context.mounted) return;
    await _addPhotos(context, ref, [picked]);
  }

  Future<void> _addPhotos(
    BuildContext context,
    WidgetRef ref,
    List<PickedImageBytes> images,
  ) async {
    if (images.isEmpty) return;
    try {
      for (final picked in images) {
        await ref
            .read(inventoryRepositoryProvider)
            .uploadNodeImage(
              homeId: homeId,
              nodeId: node.id,
              bytes: picked.bytes,
              mimeType: picked.mimeType,
              extension: picked.extension,
            );
      }
      invalidateNodeImageCaches(ref, homeId: homeId, nodeId: node.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _deletePhoto(
    BuildContext context,
    WidgetRef ref,
    EntityImage image,
  ) async {
    try {
      await ref.read(inventoryRepositoryProvider).deleteImage(image);
      invalidateNodeImageCaches(ref, homeId: homeId, nodeId: node.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
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
