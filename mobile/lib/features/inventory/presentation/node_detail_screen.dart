import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../rooms/presentation/rooms_providers.dart';

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
    final dateFormat = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(title: const Text('Item details')),
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
                Text(node.description!, style: Theme.of(context).textTheme.bodyLarge),
              ],
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
              _DetailRow(label: 'Brand', value: node.brand ?? '—'),
              _DetailRow(
                label: 'Purchase price',
                value: node.purchasePrice == null
                    ? '—'
                    : '${node.currency ?? ''} ${node.purchasePrice}'
                        .trim(),
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
            ],
          );
        },
      ),
    );
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
