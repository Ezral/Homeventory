import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../utils/inventory_labels.dart';
import '../../features/rooms/presentation/rooms_providers.dart';

Future<int?> showBulkAddItemsSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String homeId,
  required String roomId,
  String? parentNodeId,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _BulkAddItemsSheet(
      homeId: homeId,
      roomId: roomId,
      parentNodeId: parentNodeId,
    ),
  );
}

class _BulkAddItemsSheet extends ConsumerStatefulWidget {
  const _BulkAddItemsSheet({
    required this.homeId,
    required this.roomId,
    this.parentNodeId,
  });

  final String homeId;
  final String roomId;
  final String? parentNodeId;

  @override
  ConsumerState<_BulkAddItemsSheet> createState() => _BulkAddItemsSheetState();
}

class _BulkAddItemsSheetState extends ConsumerState<_BulkAddItemsSheet> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final names = parseBulkItemNames(_controller.text);
    if (names.isEmpty) return;
    setState(() => _busy = true);
    try {
      final count = await ref
          .read(inventoryRepositoryProvider)
          .createItemsFromNames(
            homeId: widget.homeId,
            roomId: widget.roomId,
            parentNodeId: widget.parentNodeId,
            names: names,
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
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add several items',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'One name per line. They land in this location as items — open any later to add photos, quantity, or barcodes.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 6,
            maxLines: 12,
            enabled: !_busy,
            decoration: const InputDecoration(
              hintText: 'USB-C charger\nPassport\nSunscreen',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            style: FilledButton.styleFrom(backgroundColor: AppColors.moss),
            child: Text(_busy ? 'Adding…' : 'Add items'),
          ),
        ],
      ),
    );
  }
}
