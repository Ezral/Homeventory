import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/inventory_node.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/entity_thumbnail.dart';
import '../../rooms/presentation/rooms_providers.dart';

/// Hierarchical move destination: room → nested containers (any depth),
/// with up/down navigation and explicit "Move here" confirmation.
class MoveNodeScreen extends ConsumerStatefulWidget {
  const MoveNodeScreen({
    super.key,
    required this.homeId,
    required this.roomId,
    required this.nodeId,
  });

  final String homeId;
  final String roomId;
  final String nodeId;

  @override
  ConsumerState<MoveNodeScreen> createState() => _MoveNodeScreenState();
}

class _MoveNodeScreenState extends ConsumerState<MoveNodeScreen> {
  String? _selectedRoomId;
  String? _browseParentId;
  final List<({String id, String name})> _crumbs = [];
  bool _initializedFromNode = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _selectedRoomId = widget.roomId;
  }

  InventoryScope get _scope => InventoryScope(
        homeId: widget.homeId,
        roomId: _selectedRoomId!,
        parentNodeId: _browseParentId,
      );

  @override
  Widget build(BuildContext context) {
    final nodeAsync = ref.watch(inventoryNodeProvider(widget.nodeId));
    final roomsAsync = ref.watch(roomsListProvider(widget.homeId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Move item'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: nodeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(inventoryNodeProvider(widget.nodeId)),
        ),
        data: (node) {
          if (!_initializedFromNode) {
            _initializedFromNode = true;
            _selectedRoomId = node.roomId;
            _browseParentId = null;
            _crumbs.clear();
          }

          final childrenAsync = ref.watch(inventoryChildrenProvider(_scope));
          final thumbsAsync = childrenAsync.maybeWhen(
            data: (nodes) => ref.watch(
              entityThumbnailsProvider(
                (
                  homeId: widget.homeId,
                  entityType: 'INVENTORY_NODE',
                  idsKey: nodes.map((n) => n.id).join(','),
                ),
              ),
            ),
            orElse: () => null,
          );
          final thumbs = thumbsAsync?.maybeWhen(
                data: (m) => m,
                orElse: () => const <String, String>{},
              ) ??
              const <String, String>{};

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  children: [
                    Text(
                      node.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Browse into any storage level, go back up, then move here.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    const SectionLabel('Room'),
                    const SizedBox(height: 8),
                    roomsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => ErrorView(message: e.toString()),
                      data: (rooms) {
                        return DropdownButtonFormField<String>(
                          // ignore: deprecated_member_use
                          value: _selectedRoomId,
                          decoration: const InputDecoration(labelText: 'Room'),
                          items: rooms
                              .map(
                                (room) => DropdownMenuItem(
                                  value: room.id,
                                  child: Text(room.name),
                                ),
                              )
                              .toList(),
                          onChanged: _busy
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedRoomId = value;
                                    _browseParentId = null;
                                    _crumbs.clear();
                                  });
                                },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const SectionLabel('Location'),
                    const SizedBox(height: 8),
                    if (_crumbs.isNotEmpty || _browseParentId != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                        _browseParentId = null;
                                        _crumbs.clear();
                                      }),
                              child: const Text('Room root'),
                            ),
                            for (var i = 0; i < _crumbs.length; i++) ...[
                              const Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: AppColors.inkMuted,
                              ),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => setState(() {
                                          _crumbs.removeRange(
                                            i + 1,
                                            _crumbs.length,
                                          );
                                          _browseParentId = _crumbs[i].id;
                                        }),
                                child: Text(_crumbs[i].name),
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (_browseParentId != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    if (_crumbs.isEmpty) {
                                      _browseParentId = null;
                                    } else {
                                      _crumbs.removeLast();
                                      _browseParentId = _crumbs.isEmpty
                                          ? null
                                          : _crumbs.last.id;
                                    }
                                  }),
                          icon: const Icon(Icons.arrow_upward),
                          label: const Text('Go up one level'),
                        ),
                      ),
                    childrenAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => ErrorView(message: e.toString()),
                      data: (nodes) {
                        final containers = nodes
                            .where(
                              (n) =>
                                  n.isContainer && n.id != widget.nodeId,
                            )
                            .toList();
                        if (containers.isEmpty) {
                          return Text(
                            _browseParentId == null
                                ? 'No containers at room root. You can still move here.'
                                : 'No nested containers here. You can move into this location.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          );
                        }
                        return Column(
                          children: [
                            for (final container in containers) ...[
                              SoftTile(
                                leading: EntityThumbnail(
                                  imageUrl: thumbs[container.id],
                                  fallback: Icons.inventory_2_outlined,
                                ),
                                title: container.name,
                                subtitle: container.kindLabel,
                                onTap: _busy
                                    ? null
                                    : () => setState(() {
                                          _crumbs.add(
                                            (
                                              id: container.id,
                                              name: container.name,
                                            ),
                                          );
                                          _browseParentId = container.id;
                                        }),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: FilledButton.icon(
                    onPressed: _busy || _selectedRoomId == null
                        ? null
                        : () => _confirmAndMove(node),
                    icon: const Icon(Icons.drive_file_move_outlined),
                    label: Text(
                      _busy
                          ? 'Moving...'
                          : _browseParentId == null
                              ? 'Move to room root'
                              : 'Move here',
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmAndMove(InventoryNode node) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move this item?'),
        content: const Text('The item and any contents will move together.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted || _selectedRoomId == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(inventoryRepositoryProvider).moveNode(
            nodeId: widget.nodeId,
            destinationRoomId: _selectedRoomId!,
            destinationParentId: _browseParentId,
          );
      ref.invalidate(inventoryNodeProvider(widget.nodeId));
      ref.invalidate(
        inventoryChildrenProvider(
          InventoryScope(
            homeId: widget.homeId,
            roomId: node.roomId,
            parentNodeId: node.parentNodeId,
          ),
        ),
      );
      ref.invalidate(
        inventoryChildrenProvider(
          InventoryScope(
            homeId: widget.homeId,
            roomId: _selectedRoomId!,
            parentNodeId: _browseParentId,
          ),
        ),
      );
      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
