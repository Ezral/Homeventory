import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../features/homes/presentation/homes_providers.dart';
import '../../features/rooms/presentation/rooms_providers.dart';
import '../models/inventory_node.dart';
import 'bulk_add_dialog.dart';

Future<int?> showBulkEditSheet({
  required BuildContext context,
  required String homeId,
  required List<InventoryNode> nodes,
}) {
  if (nodes.isEmpty) return Future.value();
  return showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _BulkEditHost(homeId: homeId, nodes: nodes),
  );
}

class _BulkEditHost extends ConsumerWidget {
  const _BulkEditHost({required this.homeId, required this.nodes});

  final String homeId;
  final List<InventoryNode> nodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref
        .watch(homeProvider(homeId))
        .maybeWhen(data: (home) => home.defaultCurrency, orElse: () => 'USD');
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final table = BulkAddTable(
      existingNodes: nodes,
      currencyLabel: currency,
      onClose: () => Navigator.of(context).pop(),
      onSave: (drafts) async {
        final count = await ref
            .read(inventoryRepositoryProvider)
            .updateBulkNodes(nodes: nodes, drafts: drafts);
        if (context.mounted) Navigator.of(context).pop(count);
      },
    );

    if (wide) {
      final height = (MediaQuery.sizeOf(context).height * 0.86).clamp(
        420.0,
        720.0,
      );
      return Dialog(
        backgroundColor: AppColors.paperElevated,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(width: 1100, height: height, child: table),
      );
    }

    return Dialog.fullscreen(
      backgroundColor: AppColors.paper,
      child: SafeArea(child: table),
    );
  }
}
