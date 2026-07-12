import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/image_pick.dart';
import '../../../shared/widgets/app_widgets.dart';
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
    final imagesAsync = ref.watch(nodeImagesProvider((homeId: homeId, nodeId: nodeId)));
    final barcodesAsync = ref.watch(nodeBarcodesProvider(nodeId));
    final dateFormat = DateFormat.yMMMd();
    final canEdit = homeAsync.maybeWhen(
      data: (h) => h.myRole?.canEditInventory ?? false,
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
              Text(node.name, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(node.kindLabel)),
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
                                    onPressed: () => _deleteImage(context, ref, image),
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
                value: node.quantity == null
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
                                    ref.invalidate(nodeBarcodesProvider(nodeId));
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

  Future<void> _addPhoto(BuildContext context, WidgetRef ref) async {
    final picked = await pickEntityImage(context);
    if (picked == null) return;
    try {
      await ref.read(inventoryRepositoryProvider).uploadNodeImage(
            homeId: homeId,
            nodeId: nodeId,
            bytes: picked.bytes,
            mimeType: picked.mimeType,
            extension: picked.extension,
          );
      ref.invalidate(nodeImagesProvider((homeId: homeId, nodeId: nodeId)));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
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
      await ref.read(inventoryRepositoryProvider).addBarcode(
            homeId: homeId,
            nodeId: nodeId,
            barcodeValue: value,
          );
      ref.invalidate(nodeBarcodesProvider(nodeId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkMuted,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}
