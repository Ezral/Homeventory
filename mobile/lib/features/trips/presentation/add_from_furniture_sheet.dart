import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/inventory_node.dart';
import '../../../shared/models/room.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../rooms/presentation/rooms_providers.dart';
import '../data/trips_repository.dart';
import 'trips_providers.dart';

enum _PackSource { furniture, room }

/// Multi-step sheet: pick bag → pick furniture or room → multi-select
/// non-furniture items.
class AddFromFurnitureSheet extends ConsumerStatefulWidget {
  const AddFromFurnitureSheet({
    super.key,
    required this.homeId,
    required this.tripId,
    required this.containers,
  });

  final String homeId;
  final String tripId;
  final List<TripContainer> containers;

  @override
  ConsumerState<AddFromFurnitureSheet> createState() =>
      _AddFromFurnitureSheetState();
}

class _AddFromFurnitureSheetState extends ConsumerState<AddFromFurnitureSheet> {
  String? _bagId;
  _PackSource _source = _PackSource.furniture;
  InventoryNode? _furnitureRoot;
  Room? _room;
  final Set<String> _selected = {};
  bool _busy = false;
  String _query = '';

  bool get _pickingSource => _furnitureRoot == null && _room == null;

  @override
  void initState() {
    super.initState();
    if (widget.containers.length == 1) {
      _bagId = widget.containers.first.inventoryNodeId;
    }
  }

  void _clearSource() {
    setState(() {
      _furnitureRoot = null;
      _room = null;
      _selected.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _furnitureRoot != null
        ? 'Items under ${_furnitureRoot!.name}'
        : _room != null
            ? 'Items in ${_room!.name}'
            : 'Add to packing plan';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (_pickingSource) ...[
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _bagId,
                  decoration: const InputDecoration(
                    labelText: 'Pack into (luggage)',
                  ),
                  items: [
                    for (final c in widget.containers)
                      DropdownMenuItem(
                        value: c.inventoryNodeId,
                        child: Text(c.node?.name ?? 'Container'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _bagId = v),
                ),
                const SizedBox(height: 12),
                SegmentedButton<_PackSource>(
                  segments: const [
                    ButtonSegment(
                      value: _PackSource.furniture,
                      label: Text('Furniture'),
                      icon: Icon(Icons.weekend_outlined),
                    ),
                    ButtonSegment(
                      value: _PackSource.room,
                      label: Text('Room'),
                      icon: Icon(Icons.meeting_room_outlined),
                    ),
                  ],
                  selected: {_source},
                  onSelectionChanged: (next) {
                    setState(() {
                      _source = next.first;
                      _query = '';
                      _selected.clear();
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (_source == _PackSource.furniture) ...[
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search furniture / storage',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 10),
                  Expanded(child: _furniturePicker()),
                ] else ...[
                  Expanded(child: _roomPicker()),
                ],
              ] else ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _clearSource,
                    icon: const Icon(Icons.arrow_back),
                    label: Text(
                      _source == _PackSource.furniture
                          ? 'Back to furniture list'
                          : 'Back to rooms',
                    ),
                  ),
                ),
                Text(
                  'Items only (no furniture or storage)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                ),
                const SizedBox(height: 4),
                Expanded(child: _itemPicker()),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _busy || _selected.isEmpty || _bagId == null
                      ? null
                      : _addSelected,
                  icon: const Icon(Icons.playlist_add_check),
                  label: Text(
                    _busy
                        ? 'Adding...'
                        : 'Add ${_selected.length} to packing plan',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _furniturePicker() {
    final search = _query.trim().isEmpty
        ? null
        : ref.watch(
            inventorySearchProvider((homeId: widget.homeId, query: _query)),
          );

    if (search == null) {
      return const EmptyState(
        icon: Icons.weekend_outlined,
        title: 'Find furniture or storage',
        message:
            'Search a dresser, cabinet, or shelf. You will multi-select items under it (furniture and storage are hidden).',
      );
    }

    return search.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (nodes) {
        // Browse roots are furniture / storage (or other non-item containers).
        final list = nodes
            .where(
              (n) =>
                  n.nodeKind == InventoryNodeKind.furniture ||
                  n.nodeKind == InventoryNodeKind.storageLocation ||
                  (n.isContainer && n.nodeKind != InventoryNodeKind.item),
            )
            .toList();
        if (list.isEmpty) {
          return const EmptyState(
            title: 'No furniture found',
            message: 'Try another name.',
          );
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final node = list[index];
            return SoftTile(
              title: node.name,
              subtitle: node.kindLabel,
              onTap: _bagId == null
                  ? null
                  : () => setState(() {
                        _furnitureRoot = node;
                        _room = null;
                        _selected.clear();
                      }),
            );
          },
        );
      },
    );
  }

  Widget _roomPicker() {
    final roomsAsync = ref.watch(roomsListProvider(widget.homeId));
    return roomsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (rooms) {
        if (rooms.isEmpty) {
          return const EmptyState(
            icon: Icons.meeting_room_outlined,
            title: 'No rooms yet',
            message: 'Add a room before packing from one.',
          );
        }
        return ListView.separated(
          itemCount: rooms.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final room = rooms[index];
            return SoftTile(
              title: room.name,
              subtitle: room.description,
              onTap: _bagId == null
                  ? null
                  : () => setState(() {
                        _room = room;
                        _furnitureRoot = null;
                        _selected.clear();
                      }),
            );
          },
        );
      },
    );
  }

  Widget _itemPicker() {
    final AsyncValue<List<DescendantNode>> async;
    if (_furnitureRoot != null) {
      async = ref.watch(nodeDescendantsProvider(_furnitureRoot!.id));
    } else if (_room != null) {
      async = ref.watch(roomPackableNodesProvider(_room!.id));
    } else {
      return const SizedBox.shrink();
    }

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (descendants) {
        final items = descendants
            .where((d) => d.id != _bagId)
            .where((d) => d.nodeKind == InventoryNodeKind.item)
            .toList();
        if (items.isEmpty) {
          return const EmptyState(
            title: 'No packable items',
            message:
                'Only items (not furniture or storage) can be added to the packing plan.',
          );
        }
        return Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    if (_selected.length == items.length) {
                      _selected.clear();
                    } else {
                      _selected
                        ..clear()
                        ..addAll(items.map((e) => e.id));
                    }
                  });
                },
                child: Text(
                  _selected.length == items.length
                      ? 'Clear selection'
                      : 'Select all (${items.length})',
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final checked = _selected.contains(item.id);
                  return CheckboxListTile(
                    value: checked,
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.name),
                    subtitle: Text(
                      item.pathLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                    ),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(item.id);
                        } else {
                          _selected.remove(item.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addSelected() async {
    if (_bagId == null || _selected.isEmpty) return;
    setState(() => _busy = true);
    try {
      final count = await ref.read(tripsRepositoryProvider).addItemsToPackingPlan(
            tripId: widget.tripId,
            nodeIds: _selected.toList(),
            packedIntoNodeId: _bagId!,
          );
      if (!mounted) return;
      Navigator.pop(context, count);
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
