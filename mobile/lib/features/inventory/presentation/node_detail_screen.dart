import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/inventory_node.dart';
import '../../../shared/utils/image_pick.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/home_invite_sheet.dart';
import '../../../shared/widgets/home_shell_bottom_nav.dart';
import '../../homes/presentation/homes_providers.dart';
import '../../rooms/presentation/rooms_providers.dart';
import '../data/inventory_repository.dart';
import 'barcode_scan_screen.dart';

class NodeDetailScreen extends ConsumerWidget {
  const NodeDetailScreen({
    super.key,
    required this.homeId,
    required this.roomId,
    required this.nodeId,
  });

  final String homeId;
  final String roomId;
  final String nodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodeAsync = ref.watch(inventoryNodeProvider(nodeId));
    final homeAsync = ref.watch(homeProvider(homeId));
    final imagesAsync = ref.watch(
      nodeImagesProvider((homeId: homeId, nodeId: nodeId)),
    );
    final barcodesAsync = ref.watch(nodeBarcodesProvider(nodeId));
    final transactionsAsync = ref.watch(inventoryTransactionsProvider(nodeId));
    final dateFormat = DateFormat.yMMMd();
    final canEdit = homeAsync.maybeWhen(
      data: (h) => h.myRole?.canEditInventory ?? false,
      orElse: () => false,
    );
    final canInvite = homeAsync.maybeWhen(
      data: (h) => h.myRole?.canManageMembers ?? false,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (canEdit)
            IconButton(
              tooltip: 'Move',
              icon: const Icon(Icons.drive_file_move_outlined),
              onPressed: () async {
                final moved = await context.push<bool>(
                  '/homes/$homeId/rooms/$roomId/nodes/$nodeId/move',
                );
                if (moved == true) {
                  ref.invalidate(inventoryNodeProvider(nodeId));
                  ref.invalidate(inventoryTransactionsProvider(nodeId));
                }
              },
            ),
          if (canEdit)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await context.push(
                  '/homes/$homeId/rooms/$roomId/nodes/$nodeId/edit',
                );
                ref.invalidate(inventoryNodeProvider(nodeId));
              },
            ),
        ],
      ),
      bottomNavigationBar: HomeShellBottomNav(
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
              if (!canEdit) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('You do not have permission to add objects.'),
                  ),
                );
                return;
              }
              final node = nodeAsync.asData?.value;
              final parent = node != null &&
                      (node.isContainer || node.isMobileContainer)
                  ? nodeId
                  : null;
              await context.push(
                parent == null
                    ? '/homes/$homeId/rooms/$roomId/nodes/new'
                    : '/homes/$homeId/rooms/$roomId/nodes/new?parent=$parent',
              );
              if (parent != null) {
                ref.invalidate(
                  inventoryChildrenProvider(
                    InventoryScope(
                      homeId: homeId,
                      roomId: roomId,
                      parentNodeId: parent,
                    ),
                  ),
                );
              }
          }
        },
      ),
      body: nodeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(inventoryNodeProvider(nodeId)),
        ),
        data: (node) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                node.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(node.kindLabel)),
                  if (node.isDispenser)
                    Chip(
                      label: Text(
                        'Dispenser · ${node.effectiveDispenserMode.label}',
                      ),
                    ),
                  if (node.isDispensable) const Chip(label: Text('Dispensable')),
                  if (node.isDisposed) const Chip(label: Text('Disposed')),
                  if (node.itemCategory != null)
                    Chip(label: Text(node.itemCategory!.label)),
                ],
              ),
              if (node.description != null && node.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  node.description!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              const SizedBox(height: 24),
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
                        return Stack(
                          children: [
                            ClipRRect(
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
                            ),
                            if (canEdit)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Material(
                                  color: Colors.black54,
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    iconSize: 18,
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                    color: Colors.white,
                                    icon: const Icon(Icons.close),
                                    onPressed: () =>
                                        _deleteImage(context, ref, image),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const SectionLabel('Details'),
              const SizedBox(height: 12),
              _DetailRow(
                label: 'Quantity',
                value: node.isDispenser &&
                        node.effectiveDispenserMode == DispenserMode.multi
                    ? 'Per chamber (below)'
                    : node.quantity == null
                        ? '—'
                        : [
                            node.quantity == node.quantity!.roundToDouble()
                                ? node.quantity!.toInt().toString()
                                : node.quantity.toString(),
                            if (node.quantityUnit != null) node.quantityUnit!,
                          ].join(' '),
              ),
              _DetailRow(
                label: 'Min quantity',
                value: node.minimumQuantity?.toString() ?? '—',
              ),
              _DetailRow(
                label: 'Capacity',
                value: node.capacity == null
                    ? '—'
                    : [
                        _formatQty(node.capacity!),
                        if (node.quantityUnit != null) node.quantityUnit!,
                        if (node.isDispenser &&
                            node.effectiveDispenserMode == DispenserMode.multi)
                          'per chamber',
                      ].join(' '),
              ),
              _DetailRow(
                label: 'Dispenser',
                value: node.isDispenser
                    ? node.effectiveDispenserMode.label
                    : 'No',
              ),
              if (node.isDispensable)
                _DetailRow(
                  label: 'Consumable form',
                  value: node.consumableForm?.label ?? 'Not set',
                ),
              if (node.disposedAt != null)
                _DetailRow(
                  label: 'Disposed',
                  value: dateFormat.format(node.disposedAt!),
                ),
              if (node.isDispenser) ...[
                const SizedBox(height: 24),
                const SectionLabel('Dispenser products'),
                const SizedBox(height: 8),
                Text(
                  node.effectiveDispenserMode == DispenserMode.multi
                      ? node.capacity == null
                          ? 'Each slot is an independent chamber. Set capacity on edit, then use/refill per product.'
                          : 'Each linked product fills its own ${_formatQty(node.capacity!)}${node.quantityUnit != null ? ' ${node.quantityUnit}' : ' CC'} chamber. Use and refill per slot.'
                      : 'Link one dispensable product to this dispenser.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                ),
                const SizedBox(height: 12),
                _DispenserSlotsSection(
                  homeId: homeId,
                  roomId: roomId,
                  dispenser: node,
                  canEdit: canEdit && !node.isDisposed,
                ),
              ],
              _DetailRow(label: 'Brand', value: node.brand ?? '—'),
              _DetailRow(
                label: 'Weight',
                value: node.weight == null
                    ? '—'
                    : [
                        node.weight == node.weight!.roundToDouble()
                            ? node.weight!.toInt().toString()
                            : node.weight.toString(),
                        if (node.weightUnit != null) node.weightUnit!,
                      ].join(' '),
              ),
              _DetailRow(
                label: 'Purchase price',
                value: node.purchasePrice == null
                    ? '—'
                    : '${node.currency ?? ''} ${node.purchasePrice}'.trim(),
              ),
              _DetailRow(
                label: 'Purchase date',
                value: node.purchaseDate == null
                    ? '—'
                    : dateFormat.format(node.purchaseDate!),
              ),
              _DetailRow(
                label: 'Expires',
                value: node.expirationDate == null
                    ? '—'
                    : dateFormat.format(node.expirationDate!),
              ),
              if (canEdit && !node.isDisposed) ...[
                const SizedBox(height: 24),
                const SectionLabel('Stock actions'),
                const SizedBox(height: 12),
                if (node.isDispenser &&
                    node.effectiveDispenserMode == DispenserMode.multi)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Use and refill each chamber under Dispenser products.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                    ),
                  ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (!(node.isDispenser &&
                        node.effectiveDispenserMode == DispenserMode.multi)) ...[
                      FilledButton.tonalIcon(
                        onPressed: () => _quantityAction(
                          context,
                          ref,
                          node,
                          InventoryTransactionType.use,
                        ),
                        icon: const Icon(Icons.remove_circle_outline),
                        label: const Text('Use'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _quantityAction(
                          context,
                          ref,
                          node,
                          InventoryTransactionType.restock,
                        ),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Restock'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _quantityAction(
                          context,
                          ref,
                          node,
                          InventoryTransactionType.adjustment,
                        ),
                        icon: const Icon(Icons.tune),
                        label: const Text('Adjust'),
                      ),
                    ],
                    OutlinedButton.icon(
                      onPressed: () => _disposeNode(context, ref, node),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Dispose'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              const SectionLabel('Transaction history'),
              const SizedBox(height: 8),
              transactionsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(e.toString()),
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return Text(
                      'No transactions yet.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    );
                  }
                  return Column(
                    children: [
                      for (final transaction in transactions)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(_transactionIcon(transaction)),
                          title: Text(transaction.transactionType.label),
                          subtitle: Text(
                            [
                              dateFormat.format(transaction.createdAt),
                              if (transaction.slotNumber != null)
                                'Slot ${transaction.slotNumber}',
                              if (transaction.reason != null)
                                transaction.reason!,
                            ].join(' · '),
                          ),
                          trailing: Text(_transactionQuantity(transaction)),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: SectionLabel('Barcodes')),
                  if (canEdit) ...[
                    IconButton(
                      tooltip: 'Scan barcode',
                      onPressed: () => _addBarcode(context, ref, scan: true),
                      icon: const Icon(Icons.qr_code_scanner),
                    ),
                    IconButton(
                      tooltip: 'Enter barcode',
                      onPressed: () => _addBarcode(context, ref, scan: false),
                      icon: const Icon(Icons.edit),
                    ),
                  ],
                ],
              ),
              barcodesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(e.toString()),
                data: (barcodes) {
                  if (barcodes.isEmpty) {
                    return Text(
                      'No barcodes linked.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    );
                  }
                  return Column(
                    children: [
                      for (final code in barcodes)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.qr_code_2),
                          title: Text(code.barcodeValue),
                          subtitle: Text(code.barcodeFormat ?? 'Barcode'),
                          trailing: canEdit
                              ? IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    await ref
                                        .read(inventoryRepositoryProvider)
                                        .removeBarcode(code.id);
                                    ref.invalidate(
                                      nodeBarcodesProvider(nodeId),
                                    );
                                  },
                                )
                              : null,
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _quantityAction(
    BuildContext context,
    WidgetRef ref,
    InventoryNode node,
    InventoryTransactionType type,
  ) async {
    final current = node.quantity ?? 0;
    final unit = node.quantityUnit?.trim().isNotEmpty == true
        ? node.quantityUnit!
        : 'unit';
    final controller = TextEditingController(
      text: type == InventoryTransactionType.adjustment
          ? _formatQty(current)
          : '',
    );
    final quantity = await showDialog<double>(
      context: context,
      builder: (context) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(type.label),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      'Current: ${_formatQty(current)} $unit',
                      if (node.capacity != null)
                        'Capacity: ${_formatQty(node.capacity!)} $unit',
                    ].join('\n'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: type == InventoryTransactionType.adjustment
                          ? 'New quantity ($unit)'
                          : 'Quantity ($unit)',
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = double.tryParse(controller.text.trim());
                    final valid =
                        value != null &&
                        (type == InventoryTransactionType.adjustment
                            ? value >= 0
                            : value > 0);
                    if (!valid) {
                      setDialogState(() {
                        errorText = type == InventoryTransactionType.adjustment
                            ? 'Enter zero or more'
                            : 'Enter more than zero';
                      });
                      return;
                    }
                    Navigator.pop(context, value);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (quantity == null || !context.mounted) return;

    final delta = type == InventoryTransactionType.adjustment
        ? quantity - current
        : quantity;
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .applyTransaction(
            nodeId: node.id,
            transactionType: type,
            quantityDelta: delta,
            quantityUnit: unit,
            reason: type.label,
          );
      _invalidateNode(ref, node);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _disposeNode(
    BuildContext context,
    WidgetRef ref,
    InventoryNode node,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dispose this item?'),
        content: const Text(
          'Disposed items are hidden from inventory lists and search.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dispose'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await ref
          .read(inventoryRepositoryProvider)
          .applyTransaction(
            nodeId: node.id,
            transactionType: InventoryTransactionType.dispose,
            reason: 'Disposed',
          );
      _invalidateNode(ref, node);
      if (context.mounted) context.pop(true);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _invalidateNode(WidgetRef ref, InventoryNode node) {
    ref.invalidate(inventoryNodeProvider(node.id));
    ref.invalidate(inventoryTransactionsProvider(node.id));
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

  Future<void> _addPhoto(BuildContext context, WidgetRef ref) async {
    final picked = await pickEntityImage(context);
    if (picked == null) return;
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .uploadNodeImage(
            homeId: homeId,
            nodeId: nodeId,
            bytes: picked.bytes,
            mimeType: picked.mimeType,
            extension: picked.extension,
          );
      ref.invalidate(nodeImagesProvider((homeId: homeId, nodeId: nodeId)));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _deleteImage(
    BuildContext context,
    WidgetRef ref,
    EntityImage image,
  ) async {
    try {
      await ref.read(inventoryRepositoryProvider).deleteImage(image);
      ref.invalidate(nodeImagesProvider((homeId: homeId, nodeId: nodeId)));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _addBarcode(
    BuildContext context,
    WidgetRef ref, {
    required bool scan,
  }) async {
    String? value;
    if (scan) {
      value = await context.push<String>('/homes/$homeId/scan-barcode');
    } else {
      value = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const BarcodeManualEntrySheet(),
      );
    }
    if (value == null || value.trim().isEmpty) return;
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .addBarcode(homeId: homeId, nodeId: nodeId, barcodeValue: value);
      ref.invalidate(nodeBarcodesProvider(nodeId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  IconData _transactionIcon(InventoryTransaction transaction) {
    return switch (transaction.transactionType) {
      InventoryTransactionType.use => Icons.remove_circle_outline,
      InventoryTransactionType.restock => Icons.add_circle_outline,
      InventoryTransactionType.adjustment => Icons.tune,
      InventoryTransactionType.dispose => Icons.delete_outline,
      InventoryTransactionType.transferRefill => Icons.swap_horiz,
      InventoryTransactionType.move => Icons.drive_file_move_outlined,
      InventoryTransactionType.initialStock => Icons.inventory_2_outlined,
    };
  }

  String _transactionQuantity(InventoryTransaction transaction) {
    final value = transaction.quantityDelta;
    if (value == null || value == 0) return '—';
    final sign = value > 0 ? '+' : '';
    return [
      '$sign${_formatQty(value)}',
      if (transaction.quantityUnit != null) transaction.quantityUnit!,
    ].join(' ');
  }

  String _formatQty(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}

class _DispenserSlotsSection extends ConsumerWidget {
  const _DispenserSlotsSection({
    required this.homeId,
    required this.roomId,
    required this.dispenser,
    required this.canEdit,
  });

  final String homeId;
  final String roomId;
  final InventoryNode dispenser;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(
      dispenserAssignmentsProvider(dispenser.id),
    );

    return assignmentsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text(e.toString()),
      data: (assignments) {
        final bySlot = {
          for (final a in assignments) a.slotNumber: a,
        };
        final maxSlots = dispenser.effectiveDispenserMode.maxSlots;
        final isMulti =
            dispenser.effectiveDispenserMode == DispenserMode.multi;
        return Column(
          children: [
            for (var slot = 1; slot <= maxSlots; slot++) ...[
              if (slot > 1) const SizedBox(height: 12),
              _slotCard(
                context: context,
                ref: ref,
                slotNumber: slot,
                assignment: bySlot[slot],
                isMulti: isMulti,
              ),
            ],
            if (canEdit)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    await context.push(
                      '/homes/$homeId/rooms/$roomId/nodes/new',
                    );
                    ref.invalidate(
                      dispensableProductsProvider((
                        homeId: homeId,
                        excludeNodeId: dispenser.id,
                      )),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create dispensable product'),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _slotCard({
    required BuildContext context,
    required WidgetRef ref,
    required int slotNumber,
    required DispenserProductAssignment? assignment,
    required bool isMulti,
  }) {
    final empty = assignment == null;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.mossSoft.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.paperElevated,
                child: Text('$slotNumber'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      empty
                          ? 'Empty slot'
                          : (assignment.productName ?? 'Product'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      empty
                          ? 'No product linked'
                          : isMulti
                              ? 'Chamber ${assignment.fillLabel}'
                              : 'Linked product',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                    ),
                  ],
                ),
              ),
              if (canEdit)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => _assignSlot(
                        context,
                        ref,
                        slotNumber: slotNumber,
                      ),
                      child: Text(empty ? 'Assign' : 'Change'),
                    ),
                    if (!empty)
                      IconButton(
                        tooltip: 'Clear slot',
                        onPressed: () => _clearSlot(
                          context,
                          ref,
                          slotNumber: slotNumber,
                        ),
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
            ],
          ),
          if (canEdit && isMulti && !empty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _slotQuantityAction(
                    context,
                    ref,
                    assignment: assignment,
                    type: InventoryTransactionType.use,
                  ),
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  label: const Text('Use'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _slotQuantityAction(
                    context,
                    ref,
                    assignment: assignment,
                    type: InventoryTransactionType.restock,
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Refill'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _slotQuantityAction(
                    context,
                    ref,
                    assignment: assignment,
                    type: InventoryTransactionType.adjustment,
                  ),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Adjust'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _slotQuantityAction(
    BuildContext context,
    WidgetRef ref, {
    required DispenserProductAssignment assignment,
    required InventoryTransactionType type,
  }) async {
    final unit = assignment.quantityUnit?.trim().isNotEmpty == true
        ? assignment.quantityUnit!
        : (dispenser.quantityUnit?.trim().isNotEmpty == true
              ? dispenser.quantityUnit!
              : 'CC');
    final current = assignment.quantity;
    final capacity = assignment.capacity ?? dispenser.capacity;
    final controller = TextEditingController(
      text: type == InventoryTransactionType.adjustment
          ? (current == current.roundToDouble()
                ? current.toInt().toString()
                : current.toString())
          : '',
    );
    final label = assignment.productName ?? 'Slot ${assignment.slotNumber}';
    final quantity = await showDialog<double>(
      context: context,
      builder: (context) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('${type == InventoryTransactionType.restock ? 'Refill' : type.label} · $label'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      'Current: ${assignment.fillLabel}',
                      if (capacity != null)
                        'Chamber capacity: ${capacity == capacity.roundToDouble() ? capacity.toInt() : capacity} $unit',
                    ].join('\n'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: type == InventoryTransactionType.adjustment
                          ? 'New quantity ($unit)'
                          : 'Quantity ($unit)',
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = double.tryParse(controller.text.trim());
                    final valid = value != null &&
                        (type == InventoryTransactionType.adjustment
                            ? value >= 0
                            : value > 0);
                    if (!valid) {
                      setDialogState(() {
                        errorText = type == InventoryTransactionType.adjustment
                            ? 'Enter zero or more'
                            : 'Enter more than zero';
                      });
                      return;
                    }
                    Navigator.pop(context, value);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (quantity == null || !context.mounted) return;

    final delta = type == InventoryTransactionType.adjustment
        ? quantity - current
        : quantity;
    try {
      await ref.read(inventoryRepositoryProvider).applyTransaction(
            nodeId: dispenser.id,
            transactionType: type,
            quantityDelta: delta,
            quantityUnit: unit,
            reason: '${type.label} · $label',
            slotNumber: assignment.slotNumber,
          );
      ref.invalidate(dispenserAssignmentsProvider(dispenser.id));
      ref.invalidate(inventoryTransactionsProvider(dispenser.id));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _assignSlot(
    BuildContext context,
    WidgetRef ref, {
    required int slotNumber,
  }) async {
    final productsAsync = ref.read(
      dispensableProductsProvider((
        homeId: homeId,
        excludeNodeId: dispenser.id,
      )).future,
    );
    List<InventoryNode> products;
    try {
      products = await productsAsync;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return;
    }

    if (!context.mounted) return;
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No dispensable products yet. Create one and mark it dispensable.',
          ),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<InventoryNode>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Assign to slot $slotNumber',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final product in products)
                ListTile(
                  title: Text(product.name),
                  subtitle: Text(
                    [
                      if (product.consumableForm != null)
                        product.consumableForm!.label,
                      if (product.quantity != null)
                        [
                          product.quantity ==
                                  product.quantity!.roundToDouble()
                              ? product.quantity!.toInt().toString()
                              : product.quantity.toString(),
                          if (product.quantityUnit != null)
                            product.quantityUnit!,
                        ].join(' '),
                    ].where((e) => e.isNotEmpty).join(' · '),
                  ),
                  onTap: () => Navigator.of(context).pop(product),
                ),
            ],
          ),
        );
      },
    );
    if (selected == null) return;

    try {
      await ref.read(inventoryRepositoryProvider).assignProductToDispenser(
            dispenserItemId: dispenser.id,
            productItemId: selected.id,
            slotNumber: slotNumber,
          );
      ref.invalidate(dispenserAssignmentsProvider(dispenser.id));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _clearSlot(
    BuildContext context,
    WidgetRef ref, {
    required int slotNumber,
  }) async {
    try {
      await ref.read(inventoryRepositoryProvider).clearDispenserSlot(
            dispenserItemId: dispenser.id,
            slotNumber: slotNumber,
          );
      ref.invalidate(dispenserAssignmentsProvider(dispenser.id));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}
