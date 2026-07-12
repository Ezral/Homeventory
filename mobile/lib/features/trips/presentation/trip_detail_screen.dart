import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/inventory_node.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../homes/presentation/homes_providers.dart';
import '../../rooms/presentation/rooms_providers.dart';
import '../data/trips_repository.dart';
import 'trips_providers.dart';

class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({
    super.key,
    required this.homeId,
    required this.tripId,
  });

  final String homeId;
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripProvider(tripId));
    final containersAsync = ref.watch(tripContainersProvider(tripId));
    final itemsAsync = ref.watch(tripItemsProvider(tripId));
    final homeAsync = ref.watch(homeProvider(homeId));
    final canEdit = homeAsync.maybeWhen(
      data: (home) => home.myRole?.canEditInventory ?? false,
      orElse: () => false,
    );
    final dateFormat = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(title: const Text('Trip')),
      body: tripAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(tripProvider(tripId)),
        ),
        data: (trip) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(tripProvider(tripId));
              ref.invalidate(tripContainersProvider(tripId));
              ref.invalidate(tripItemsProvider(tripId));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  trip.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text(trip.status.label)),
                    Chip(
                      label: Text(
                        'Created ${dateFormat.format(trip.createdAt)}',
                      ),
                    ),
                  ],
                ),
                if (trip.notes != null && trip.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(trip.notes!),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: SectionLabel('Mobile containers')),
                    if (canEdit)
                      TextButton.icon(
                        onPressed: () => _assignContainer(context, ref),
                        icon: const Icon(Icons.add),
                        label: const Text('Assign'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                containersAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ErrorView(message: e.toString()),
                  data: (containers) {
                    if (containers.isEmpty) {
                      return Text(
                        'Assign a mobile container before packing items.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      );
                    }
                    return Column(
                      children: [
                        for (final container in containers) ...[
                          SoftTile(
                            leading: const _IconBadge(Icons.luggage_outlined),
                            title: container.node?.name ?? 'Container',
                            subtitle: container.node?.kindLabel,
                            onTap: container.node == null
                                ? null
                                : () => context.push(
                                    '/homes/$homeId/rooms/${container.node!.roomId}/nodes/${container.node!.id}',
                                  ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(child: SectionLabel('Packed items')),
                    if (canEdit)
                      containersAsync.maybeWhen(
                        data: (containers) => TextButton.icon(
                          onPressed: containers.isEmpty
                              ? null
                              : () => _packItem(context, ref, containers),
                          icon: const Icon(Icons.add_box_outlined),
                          label: const Text('Pack'),
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                itemsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ErrorView(message: e.toString()),
                  data: (items) {
                    if (items.isEmpty) {
                      return Text(
                        'No items packed yet.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      );
                    }
                    return Column(
                      children: [
                        for (final item in items) ...[
                          SoftTile(
                            leading: _IconBadge(
                              item.status == TripItemStatus.packed
                                  ? Icons.inventory_2_outlined
                                  : Icons.undo,
                            ),
                            title: item.node?.name ?? 'Packed item',
                            subtitle: [
                              item.status.label,
                              if (item.packedIntoNode != null)
                                'in ${item.packedIntoNode!.name}',
                            ].join(' · '),
                            trailing:
                                canEdit && item.status == TripItemStatus.packed
                                ? TextButton(
                                    onPressed: () =>
                                        _unpackItem(context, ref, item),
                                    child: const Text('Unpack'),
                                  )
                                : null,
                            onTap: item.node == null
                                ? null
                                : () => context.push(
                                    '/homes/$homeId/rooms/${item.node!.roomId}/nodes/${item.node!.id}/details',
                                  ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _assignContainer(BuildContext context, WidgetRef ref) async {
    final assigned = await ref.read(tripContainersProvider(tripId).future);
    final assignedIds = assigned.map((c) => c.inventoryNodeId).toSet();
    if (!context.mounted) return;

    final node = await showModalBottomSheet<InventoryNode>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final containersAsync = ref.watch(mobileContainersProvider(homeId));
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.75,
                  ),
                  child: containersAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => ErrorView(message: e.toString()),
                    data: (containers) {
                      final available = containers
                          .where((n) => !assignedIds.contains(n.id))
                          .toList();
                      if (available.isEmpty) {
                        return const EmptyState(
                          icon: Icons.luggage_outlined,
                          title: 'No mobile containers',
                          message:
                              'Create an item marked as a mobile container first.',
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: available.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final container = available[index];
                          return SoftTile(
                            leading: const _IconBadge(Icons.luggage_outlined),
                            title: container.name,
                            subtitle: container.kindLabel,
                            onTap: () => Navigator.pop(context, container),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (node == null || !context.mounted) return;

    try {
      await ref
          .read(tripsRepositoryProvider)
          .assignContainer(tripId: tripId, nodeId: node.id);
      ref.invalidate(tripContainersProvider(tripId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _packItem(
    BuildContext context,
    WidgetRef ref,
    List<TripContainer> containers,
  ) async {
    final selection = await showModalBottomSheet<_PackSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _PackItemSheet(homeId: homeId, containers: containers),
    );
    if (selection == null || !context.mounted) return;

    try {
      await ref
          .read(tripsRepositoryProvider)
          .packItem(
            tripId: tripId,
            nodeId: selection.node.id,
            packedIntoNodeId: selection.containerId,
          );
      _invalidateTrip(ref);
      _invalidateMovedNode(ref, selection.node);
      ref.invalidate(inventoryNodeProvider(selection.containerId));
      ref.invalidate(
        inventoryChildrenProvider(
          InventoryScope(
            homeId: homeId,
            roomId: selection.node.roomId,
            parentNodeId: selection.containerId,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _unpackItem(
    BuildContext context,
    WidgetRef ref,
    TripItem item,
  ) async {
    try {
      await ref.read(tripsRepositoryProvider).unpackItem(item.id);
      _invalidateTrip(ref);
      if (item.node != null) _invalidateMovedNode(ref, item.node!);
      ref.invalidate(inventoryNodeProvider(item.inventoryNodeId));
      ref.invalidate(inventoryNodeProvider(item.packedIntoNodeId));
      ref.invalidate(
        inventoryChildrenProvider(
          InventoryScope(
            homeId: item.homeId,
            roomId: item.originalRoomId,
            parentNodeId: item.originalParentNodeId,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _invalidateTrip(WidgetRef ref) {
    ref.invalidate(tripProvider(tripId));
    ref.invalidate(tripContainersProvider(tripId));
    ref.invalidate(tripItemsProvider(tripId));
  }

  void _invalidateMovedNode(WidgetRef ref, InventoryNode node) {
    ref.invalidate(inventoryNodeProvider(node.id));
    ref.invalidate(
      inventoryChildrenProvider(
        InventoryScope(
          homeId: node.homeId,
          roomId: node.roomId,
          parentNodeId: node.parentNodeId,
        ),
      ),
    );
  }
}

class _PackItemSheet extends ConsumerStatefulWidget {
  const _PackItemSheet({required this.homeId, required this.containers});

  final String homeId;
  final List<TripContainer> containers;

  @override
  ConsumerState<_PackItemSheet> createState() => _PackItemSheetState();
}

class _PackItemSheetState extends ConsumerState<_PackItemSheet> {
  final _controller = TextEditingController();
  String _query = '';
  InventoryNode? _selectedNode;
  String? _selectedContainerId;

  @override
  void initState() {
    super.initState();
    if (widget.containers.length == 1) {
      _selectedContainerId = widget.containers.first.inventoryNodeId;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _query.trim().isEmpty
        ? null
        : ref.watch(
            inventorySearchProvider((homeId: widget.homeId, query: _query)),
          );

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
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Pack item', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _selectedContainerId,
                decoration: const InputDecoration(labelText: 'Pack into'),
                items: widget.containers
                    .map(
                      (container) => DropdownMenuItem(
                        value: container.inventoryNodeId,
                        child: Text(container.node?.name ?? 'Container'),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedContainerId = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Search item to pack',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              if (_selectedNode != null) ...[
                const SizedBox(height: 10),
                InputChip(
                  label: Text(_selectedNode!.name),
                  onDeleted: () => setState(() => _selectedNode = null),
                ),
              ],
              const SizedBox(height: 10),
              Flexible(
                child: results == null
                    ? const EmptyState(
                        icon: Icons.search,
                        title: 'Search inventory',
                        message: 'Pick an item to pack into this trip.',
                      )
                    : results.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => ErrorView(message: e.toString()),
                        data: (nodes) {
                          final filtered = nodes
                              .where((n) => n.id != _selectedContainerId)
                              .toList();
                          if (filtered.isEmpty) {
                            return const EmptyState(
                              title: 'No matches',
                              message: 'Try a different search.',
                            );
                          }
                          return ListView.separated(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final node = filtered[index];
                              return SoftTile(
                                title: node.name,
                                subtitle: node.kindLabel,
                                onTap: () =>
                                    setState(() => _selectedNode = node),
                              );
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _selectedNode == null || _selectedContainerId == null
                    ? null
                    : () => Navigator.pop(
                        context,
                        _PackSelection(
                          node: _selectedNode!,
                          containerId: _selectedContainerId!,
                        ),
                      ),
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('Pack'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackSelection {
  const _PackSelection({required this.node, required this.containerId});

  final InventoryNode node;
  final String containerId;
}

class _IconBadge extends StatelessWidget {
  const _IconBadge(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.mossSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppColors.mossDeep),
    );
  }
}
