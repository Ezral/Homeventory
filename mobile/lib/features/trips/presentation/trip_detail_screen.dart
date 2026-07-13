import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/inventory_node.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/entity_thumbnail.dart';
import '../../homes/presentation/homes_providers.dart';
import '../../rooms/presentation/rooms_providers.dart';
import '../data/trips_repository.dart';
import 'add_from_furniture_sheet.dart';
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
      appBar: AppBar(
        title: const Text('Trip'),
        actions: [
          if (canEdit)
            IconButton(
              tooltip: 'Edit trip',
              onPressed: () async {
                final trip = tripAsync.asData?.value;
                if (trip == null) return;
                await _editTrip(context, ref, trip);
              },
              icon: const Icon(Icons.edit_outlined),
            ),
          if (canEdit)
            IconButton(
              tooltip: 'Delete trip',
              onPressed: () => _archiveTrip(context, ref),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: tripAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(tripProvider(tripId)),
        ),
        data: (trip) {
          final weight = buildTripWeightSummary(
            trip: trip,
            containers: containersAsync.asData?.value ?? const [],
            items: itemsAsync.asData?.value ?? const [],
          );

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
                  runSpacing: 8,
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
                const SizedBox(height: 16),
                _WeightSummaryCard(
                  summary: weight,
                  onEditAllowance: canEdit
                      ? () => _editTrip(context, ref, trip)
                      : null,
                ),
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
                    final idsKey =
                        containers.map((c) => c.inventoryNodeId).join(',');
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
                    return Column(
                      children: [
                        for (final container in containers) ...[
                          SoftTile(
                            leading: EntityThumbnail(
                              imageUrl: thumbs[container.inventoryNodeId],
                              fallback: Icons.luggage_outlined,
                            ),
                            title: container.node?.name ?? 'Container',
                            subtitle: [
                              if (container.node?.kindLabel != null)
                                container.node!.kindLabel,
                              if (inventoryWeightKg(container.node) != null)
                                '${_fmtKg(inventoryWeightKg(container.node)!)} kg',
                            ].join(' · '),
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
                    const Expanded(child: SectionLabel('Packing plan')),
                    if (canEdit)
                      containersAsync.maybeWhen(
                        data: (containers) => TextButton.icon(
                          onPressed: containers.isEmpty
                              ? null
                              : () => _addFromFurniture(
                                    context,
                                    ref,
                                    containers,
                                  ),
                          icon: const Icon(Icons.playlist_add),
                          label: const Text('From furniture'),
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Check items when packed. They stay in their original furniture, greyed out there.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                ),
                const SizedBox(height: 8),
                itemsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ErrorView(message: e.toString()),
                  data: (items) {
                    final plan = items
                        .where(
                          (i) =>
                              i.status == TripItemStatus.planned ||
                              i.status == TripItemStatus.packed,
                        )
                        .toList();
                    if (plan.isEmpty) {
                      return Text(
                        'No items on the packing plan yet. Add from furniture for multi-select.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      );
                    }
                    final idsKey =
                        plan.map((i) => i.inventoryNodeId).join(',');
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
                    return Column(
                      children: [
                        for (final item in plan) ...[
                          SoftTile(
                            leading: EntityThumbnail(
                              imageUrl: thumbs[item.inventoryNodeId],
                              fallback: Icons.inventory_2_outlined,
                            ),
                            title: item.node?.name ?? 'Item',
                            subtitle: [
                              if (item.packedIntoNode != null)
                                'Bag: ${item.packedIntoNode!.name}',
                              if (inventoryWeightKg(item.node) != null)
                                '${_fmtKg(inventoryWeightKg(item.node)!)} kg',
                              item.status.label,
                            ].join(' · '),
                            dimmed: item.status == TripItemStatus.packed,
                            trailing: canEdit
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: item.status ==
                                            TripItemStatus.packed,
                                        onChanged: (checked) =>
                                            _togglePacked(
                                          context,
                                          ref,
                                          item,
                                          checked == true,
                                        ),
                                      ),
                                      if (item.status != TripItemStatus.packed)
                                        IconButton(
                                          tooltip: 'Remove from plan',
                                          onPressed: () => _removeFromPlan(
                                            context,
                                            ref,
                                            item,
                                          ),
                                          icon: const Icon(Icons.close),
                                        ),
                                    ],
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

  Future<void> _editTrip(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
  ) async {
    final nameController = TextEditingController(text: trip.name);
    final notesController = TextEditingController(text: trip.notes ?? '');
    final allowanceController = TextEditingController(
      text: trip.luggageAllowanceKg == null
          ? ''
          : _fmtKg(trip.luggageAllowanceKg!),
    );
    var status = trip.status;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Edit trip',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<TripStatus>(
                      // ignore: deprecated_member_use
                      value: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: [
                        for (final s in TripStatus.values)
                          DropdownMenuItem(value: s, child: Text(s.label)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setModalState(() => status = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: allowanceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Luggage allowance (kg)',
                        helperText: 'Airline or personal limit for this trip.',
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        if (nameController.text.trim().isEmpty) return;
                        Navigator.pop(context, true);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (saved != true || !context.mounted) {
      nameController.dispose();
      notesController.dispose();
      allowanceController.dispose();
      return;
    }

    final allowanceText = allowanceController.text.trim();
    final allowance = allowanceText.isEmpty
        ? null
        : double.tryParse(allowanceText);

    try {
      await ref.read(tripsRepositoryProvider).updateTrip(
            tripId: tripId,
            name: nameController.text,
            notes: notesController.text,
            status: status,
            luggageAllowanceKg: allowance,
            startsOn: trip.startsOn,
            endsOn: trip.endsOn,
          );
      ref.invalidate(tripProvider(tripId));
      ref.invalidate(tripsListProvider(homeId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      nameController.dispose();
      notesController.dispose();
      allowanceController.dispose();
    }
  }

  Future<void> _archiveTrip(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this trip?'),
        content: const Text(
          'It will be removed from your trips list. Packed history is kept for audit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await ref.read(tripsRepositoryProvider).archiveTrip(tripId);
      ref.invalidate(tripsListProvider(homeId));
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
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
                      final idsKey = available.map((n) => n.id).join(',');
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
                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: available.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final container = available[index];
                          return SoftTile(
                            leading: EntityThumbnail(
                              imageUrl: thumbs[container.id],
                              fallback: Icons.luggage_outlined,
                            ),
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

  Future<void> _addFromFurniture(
    BuildContext context,
    WidgetRef ref,
    List<TripContainer> containers,
  ) async {
    final added = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => AddFromFurnitureSheet(
        homeId: homeId,
        tripId: tripId,
        containers: containers,
      ),
    );
    if (added == null || !context.mounted) return;
    _invalidateTrip(ref);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added == 1
              ? 'Added 1 item to the packing plan'
              : 'Added $added items to the packing plan',
        ),
      ),
    );
  }

  Future<void> _togglePacked(
    BuildContext context,
    WidgetRef ref,
    TripItem item,
    bool pack,
  ) async {
    try {
      if (pack) {
        await ref.read(tripsRepositoryProvider).packItem(
              tripId: tripId,
              nodeId: item.inventoryNodeId,
              packedIntoNodeId: item.packedIntoNodeId,
            );
      } else {
        await ref.read(tripsRepositoryProvider).unpackItem(item.id);
      }
      _invalidateTrip(ref);
      ref.invalidate(homePackedNodesProvider(homeId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _removeFromPlan(
    BuildContext context,
    WidgetRef ref,
    TripItem item,
  ) async {
    try {
      await ref.read(tripsRepositoryProvider).removeFromPackingPlan(item.id);
      _invalidateTrip(ref);
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
    ref.invalidate(homePackedNodesProvider(homeId));
  }
}

class _WeightSummaryCard extends StatelessWidget {
  const _WeightSummaryCard({
    required this.summary,
    this.onEditAllowance,
  });

  final TripWeightSummary summary;
  final VoidCallback? onEditAllowance;

  @override
  Widget build(BuildContext context) {
    final over = summary.isOverAllowance;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: over
            ? AppColors.danger.withValues(alpha: 0.12)
            : AppColors.mossSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Luggage weight',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (onEditAllowance != null)
                TextButton(
                  onPressed: onEditAllowance,
                  child: const Text('Edit'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _weightRow(
            context,
            'Allowance',
            summary.allowanceKg == null
                ? 'Not set'
                : '${_fmtKg(summary.allowanceKg!)} kg',
          ),
          _weightRow(
            context,
            'Packed',
            '${_fmtKg(summary.packedKg)} kg',
          ),
          _weightRow(
            context,
            'Available',
            summary.availableKg == null
                ? '—'
                : '${_fmtKg(summary.availableKg!)} kg',
            emphasize: over,
          ),
          if (summary.missingWeightCount > 0) ...[
            const SizedBox(height: 6),
            Text(
              '${summary.missingWeightCount} packed object${summary.missingWeightCount == 1 ? '' : 's'} missing weight.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _weightRow(
    BuildContext context,
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkMuted,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: emphasize ? AppColors.danger : null,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

String _fmtKg(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2);
}
