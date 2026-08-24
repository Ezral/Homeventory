import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../features/trips/presentation/trips_providers.dart';
import '../models/enums.dart';
import '../models/inventory_node.dart';

Future<int?> showBulkPackSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String homeId,
  required List<InventoryNode> nodes,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _BulkPackSheet(homeId: homeId, nodes: nodes),
  );
}

class _BulkPackSheet extends ConsumerStatefulWidget {
  const _BulkPackSheet({required this.homeId, required this.nodes});

  final String homeId;
  final List<InventoryNode> nodes;

  @override
  ConsumerState<_BulkPackSheet> createState() => _BulkPackSheetState();
}

class _BulkPackSheetState extends ConsumerState<_BulkPackSheet> {
  String? _tripId;
  String? _bagId;
  bool _busy = false;

  List<InventoryNode> get _packable => widget.nodes
      .where((n) => n.nodeKind == InventoryNodeKind.item && !n.isDisposed)
      .toList();

  Future<void> _pack({required String tripId, required String bagId}) async {
    if (_packable.isEmpty) return;
    setState(() => _busy = true);
    try {
      final count = await ref
          .read(tripsRepositoryProvider)
          .addItemsToPackingPlan(
            tripId: tripId,
            nodeIds: _packable.map((n) => n.id).toList(),
            packedIntoNodeId: bagId,
          );
      if (!mounted) return;
      Navigator.of(context).pop(count);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(tripsListProvider(widget.homeId));

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: tripsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(e.toString()),
        data: (trips) {
          final open = trips
              .where(
                (t) =>
                    t.status == TripStatus.planned ||
                    t.status == TripStatus.active,
              )
              .toList();
          if (open.isEmpty) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pack into a trip',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create a planned or active trip with a bag first, then pack from here.',
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          }

          final active = open.where((t) => t.status == TripStatus.active);
          final tripId =
              _tripId ?? (active.isNotEmpty ? active.first : open.first).id;
          final bagsAsync = ref.watch(tripContainersProvider(tripId));

          return bagsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text(e.toString()),
            data: (bags) {
              final bagId = bags.isEmpty
                  ? null
                  : (_bagId != null &&
                            bags.any((b) => b.inventoryNodeId == _bagId)
                        ? _bagId
                        : bags.first.inventoryNodeId);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Pack into a trip',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _packable.isEmpty
                        ? 'Select items (not furniture or storage) to add to a packing plan.'
                        : 'Adds ${_packable.length} item${_packable.length == 1 ? '' : 's'} to the packing list. Inventory stays in place.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: tripId,
                    decoration: const InputDecoration(labelText: 'Trip'),
                    items: [
                      for (final trip in open)
                        DropdownMenuItem(
                          value: trip.id,
                          child: Text('${trip.name} · ${trip.status.label}'),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (id) => setState(() {
                            _tripId = id;
                            _bagId = null;
                          }),
                  ),
                  const SizedBox(height: 12),
                  if (bags.isEmpty)
                    const Text(
                      'This trip has no bags yet. Assign a mobile container on the trip page first.',
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: bagId,
                      decoration: const InputDecoration(labelText: 'Bag'),
                      items: [
                        for (final bag in bags)
                          DropdownMenuItem(
                            value: bag.inventoryNodeId,
                            child: Text(bag.node?.name ?? 'Bag'),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (id) => setState(() => _bagId = id),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed:
                        _busy ||
                            _packable.isEmpty ||
                            tripId.isEmpty ||
                            bagId == null
                        ? null
                        : () => _pack(tripId: tripId, bagId: bagId),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.moss,
                    ),
                    child: Text(_busy ? 'Packing…' : 'Add to packing plan'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
