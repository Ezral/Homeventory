import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/inventory_node.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../rooms/presentation/rooms_providers.dart';

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
  String? _selectedParentId;
  bool _initializedFromNode = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _selectedRoomId = widget.roomId;
  }

  @override
  Widget build(BuildContext context) {
    final nodeAsync = ref.watch(inventoryNodeProvider(widget.nodeId));
    final roomsAsync = ref.watch(roomsListProvider(widget.homeId));
    final selectedRoomId = _selectedRoomId;
    final containersAsync = selectedRoomId == null
        ? null
        : ref.watch(
            inventoryChildrenProvider(
              InventoryScope(homeId: widget.homeId, roomId: selectedRoomId),
            ),
          );

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
            _selectedParentId = node.parentNodeId;
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(node.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Choose a destination room, then optionally place it inside a container.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              const SectionLabel('Destination'),
              const SizedBox(height: 12),
              roomsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
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
                              _selectedParentId = null;
                            });
                          },
                  );
                },
              ),
              const SizedBox(height: 14),
              if (containersAsync != null)
                containersAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ErrorView(message: e.toString()),
                  data: (nodes) {
                    final containers = nodes
                        .where((n) => n.isContainer && n.id != widget.nodeId)
                        .toList();
                    final selectedParentExists =
                        _selectedParentId == null ||
                        containers.any((n) => n.id == _selectedParentId);
                    final value = selectedParentExists
                        ? _selectedParentId
                        : null;
                    return DropdownButtonFormField<String?>(
                      // ignore: deprecated_member_use
                      value: value,
                      decoration: const InputDecoration(
                        labelText: 'Container (optional)',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Room root'),
                        ),
                        for (final container in containers)
                          DropdownMenuItem<String?>(
                            value: container.id,
                            child: Text(container.name),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => setState(() {
                              _selectedParentId = value;
                            }),
                    );
                  },
                ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _busy || _selectedRoomId == null
                    ? null
                    : () => _confirmAndMove(node),
                icon: const Icon(Icons.drive_file_move_outlined),
                label: Text(_busy ? 'Moving...' : 'Move'),
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
      await ref
          .read(inventoryRepositoryProvider)
          .moveNode(
            nodeId: widget.nodeId,
            destinationRoomId: _selectedRoomId!,
            destinationParentId: _selectedParentId,
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
            parentNodeId: _selectedParentId,
          ),
        ),
      );
      ref.invalidate(
        inventoryChildrenProvider(
          InventoryScope(homeId: widget.homeId, roomId: _selectedRoomId!),
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
