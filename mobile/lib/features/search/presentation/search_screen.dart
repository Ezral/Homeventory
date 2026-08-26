import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/web_layout.dart';
import '../../../shared/models/inventory_node.dart';
import '../../../shared/utils/inventory_labels.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/bulk_edit_dialog.dart';
import '../../../shared/widgets/bulk_pack_sheet.dart';
import '../../../shared/widgets/inventory_row_card.dart';
import '../../../shared/widgets/selection_action_bar.dart';
import '../../../shared/widgets/home_shell_bottom_nav.dart';
import '../../../shared/widgets/user_menu_button.dart';
import '../../homes/presentation/homes_providers.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../rooms/presentation/rooms_providers.dart';
import '../../trips/presentation/trips_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, required this.homeId});

  final String homeId;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  final Map<String, InventoryNode> _bulkSelected = {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final value = await context.push<String>(
      '/homes/${widget.homeId}/scan-barcode',
    );
    if (value == null || value.trim().isEmpty || !mounted) return;
    setState(() {
      _query = value.trim();
      _controller.text = _query;
    });
    try {
      final node = await ref
          .read(inventoryRepositoryProvider)
          .findByBarcode(homeId: widget.homeId, barcodeValue: value);
      if (!mounted) return;
      if (node == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No item found for barcode $value')),
        );
        return;
      }
      _openNode(node.roomId, node.id, node.isContainer);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _openNode(String roomId, String nodeId, bool isContainer) {
    if (isContainer) {
      context.push('/homes/${widget.homeId}/rooms/$roomId/nodes/$nodeId');
    } else {
      context.push(
        '/homes/${widget.homeId}/rooms/$roomId/nodes/$nodeId/details',
      );
    }
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

  Future<void> _bulkEdit() async {
    final selected = _bulkSelected.values.toList();
    if (selected.isEmpty) return;
    final count = await showBulkEditSheet(
      context: context,
      homeId: widget.homeId,
      nodes: selected,
    );
    if (count == null || count <= 0) return;
    ref.invalidate(
      inventorySearchProvider((homeId: widget.homeId, query: _query)),
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
      '/homes/${widget.homeId}/rooms/${first.roomId}/nodes/${first.id}/move',
      extra: selected.map((n) => n.id).toList(),
    );
    if (moved == true) setState(_bulkSelected.clear);
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
        inventorySearchProvider((homeId: widget.homeId, query: _query)),
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
      homeId: widget.homeId,
      nodes: selected,
    );
    if (count == null) return;
    ref.invalidate(homePackedNodesProvider(widget.homeId));
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
    final desktop = isWebDesktopLayout(context);
    final canEdit = ref
        .watch(homeProvider(widget.homeId))
        .maybeWhen(
          data: (h) => h.myRole?.canEditInventory ?? false,
          orElse: () => false,
        );
    final results = _query.trim().isEmpty
        ? null
        : ref.watch(
            inventorySearchProvider((homeId: widget.homeId, query: _query)),
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        actions: [
          IconButton(
            tooltip: 'Scan barcode',
            onPressed: _scanBarcode,
            icon: const Icon(Icons.qr_code_scanner),
          ),
          if (!desktop) const UserMenuButton(),
        ],
      ),
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
              selectedIndex: HomeShellNav.search,
              addLabel: 'Add room',
              onSelect: (index) => handleHomeShellSelect(
                context: context,
                homeId: widget.homeId,
                index: index,
                canEdit: canEdit,
                addDeniedMessage: 'You do not have permission to add rooms.',
                onAdd: () async {
                  await context.push('/homes/${widget.homeId}/rooms/new');
                  ref.invalidate(roomsListProvider(widget.homeId));
                },
              ),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Name or barcode…',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: results == null
                ? const EmptyState(
                    icon: Icons.search,
                    title: 'Search this home',
                    message:
                        'Look up anything by name or barcode across rooms and nested containers.',
                  )
                : results.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => ErrorView(message: e.toString()),
                    data: (nodes) {
                      if (nodes.isEmpty) {
                        return const EmptyState(
                          title: 'No matches',
                          message:
                              'Try a different name, spelling, or barcode.',
                        );
                      }
                      final idsKey = nodes.map((n) => n.id).join(',');
                      final thumbs = ref
                          .watch(
                            entityThumbnailsProvider((
                              homeId: widget.homeId,
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
                          .watch(homePackedNodesProvider(widget.homeId))
                          .maybeWhen(
                            data: (m) => m,
                            orElse: () => const <String, PackedNodeInfo>{},
                          );

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = searchResultColumnCount(
                            availableWidth: constraints.maxWidth - 40,
                            resultCount: nodes.length,
                          );
                          return GridView.builder(
                            padding: EdgeInsets.fromLTRB(
                              20,
                              0,
                              20,
                              desktop ? 32 : 24,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisExtent: 112,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                ),
                            itemCount: nodes.length,
                            itemBuilder: (context, index) {
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
                                selected: _bulkSelected.containsKey(node.id),
                                showCheckbox:
                                    canEdit &&
                                    (desktop || _bulkSelected.isNotEmpty),
                                checked: _bulkSelected.containsKey(node.id),
                                onToggleChecked: canEdit
                                    ? () => _toggleBulk(node)
                                    : null,
                                onLongPress: canEdit
                                    ? () => _toggleBulk(node)
                                    : null,
                                onTap: () {
                                  if (_bulkSelected.isNotEmpty) {
                                    _toggleBulk(node);
                                    return;
                                  }
                                  _openNode(
                                    node.roomId,
                                    node.id,
                                    node.isContainer,
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
