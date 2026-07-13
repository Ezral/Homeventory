import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/inventory_node.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../rooms/presentation/rooms_providers.dart';
import '../data/trips_repository.dart';
import 'trips_providers.dart';

/// Multi-step sheet: pick bag → pick furniture/storage → multi-select descendants.
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
  InventoryNode? _root;
  final Set<String> _selected = {};
  bool _busy = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (widget.containers.length == 1) {
      _bagId = widget.containers.first.inventoryNodeId;
    }
  }

  @override
  Widget build(BuildContext context) {
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
              Text(
                _root == null
                    ? 'Add from furniture'
                    : 'Select items under ${_root!.name}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (_root == null) ...[
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      _root = null;
                      _selected.clear();
                    }),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to furniture list'),
                  ),
                ),
                Expanded(child: _descendantPicker()),
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
            'Search a dresser, cabinet, or shelf. You will multi-select everything under it.',
      );
    }

    return search.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (nodes) {
        final containers = nodes.where((n) => n.isContainer).toList();
        if (containers.isEmpty) {
          return const EmptyState(
            title: 'No containers found',
            message: 'Try another name.',
          );
        }
        return ListView.separated(
          itemCount: containers.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final node = containers[index];
            return SoftTile(
              title: node.name,
              subtitle: node.kindLabel,
              onTap: _bagId == null
                  ? null
                  : () => setState(() {
                        _root = node;
                        _selected.clear();
                      }),
            );
          },
        );
      },
    );
  }

  Widget _descendantPicker() {
    final root = _root;
    if (root == null) return const SizedBox.shrink();
    final async = ref.watch(nodeDescendantsProvider(root.id));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (descendants) {
        final items = descendants
            .where((d) => d.id != _bagId)
            .toList();
        if (items.isEmpty) {
          return const EmptyState(
            title: 'Nothing underneath',
            message: 'This container has no nested items yet.',
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
