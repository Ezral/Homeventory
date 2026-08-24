import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../features/homes/presentation/homes_providers.dart';
import '../../features/rooms/presentation/rooms_providers.dart';
import '../models/bulk_node_draft.dart';
import '../models/inventory_node.dart';
import 'bulk_edit_fields.dart';

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

class _BulkEditHost extends ConsumerStatefulWidget {
  const _BulkEditHost({required this.homeId, required this.nodes});

  final String homeId;
  final List<InventoryNode> nodes;

  @override
  ConsumerState<_BulkEditHost> createState() => _BulkEditHostState();
}

class _BulkEditHostState extends ConsumerState<_BulkEditHost> {
  bool _busy = false;

  Future<void> _apply(BulkNodePatch patch) async {
    if (!patch.hasChanges) return;
    setState(() => _busy = true);
    try {
      final count = await ref
          .read(inventoryRepositoryProvider)
          .updateBulkNodes(nodes: widget.nodes, patch: patch);
      if (mounted) Navigator.of(context).pop(count);
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
    final currency = ref
        .watch(homeProvider(widget.homeId))
        .maybeWhen(data: (home) => home.defaultCurrency, orElse: () => 'USD');
    final shared = sharedValuesFromNodes(widget.nodes);
    final n = widget.nodes.length;
    final body = Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Edit $n selected',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              'Shared values are filled in. Mixed fields show Mixed — '
              'leave them blank to keep each item as-is.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            BulkEditFields(
              initial: shared,
              enabled: !_busy,
              currencyLabel: currency,
              applyLabel: _busy ? 'Saving…' : 'Save $n',
              onApply: _apply,
            ),
          ],
        ),
      ),
    );

    final wide = MediaQuery.sizeOf(context).width >= 720;
    if (wide) {
      return Dialog(
        backgroundColor: AppColors.paperElevated,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: body,
        ),
      );
    }
    return Dialog.fullscreen(
      backgroundColor: AppColors.paper,
      child: SafeArea(child: body),
    );
  }
}
