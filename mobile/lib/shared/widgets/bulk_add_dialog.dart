import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../features/homes/presentation/homes_providers.dart';
import '../../features/rooms/presentation/rooms_providers.dart';
import '../models/bulk_node_draft.dart';
import '../models/enums.dart';

Future<int?> showBulkAddItemsSheet({
  required BuildContext context,
  required String homeId,
  required String roomId,
  String? parentNodeId,
}) {
  return showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _BulkAddHost(
      homeId: homeId,
      roomId: roomId,
      parentNodeId: parentNodeId,
    ),
  );
}

class _BulkAddHost extends ConsumerWidget {
  const _BulkAddHost({
    required this.homeId,
    required this.roomId,
    this.parentNodeId,
  });

  final String homeId;
  final String roomId;
  final String? parentNodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref
        .watch(homeProvider(homeId))
        .maybeWhen(data: (home) => home.defaultCurrency, orElse: () => 'USD');
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final table = BulkAddTable(
      currencyLabel: currency,
      onClose: () => Navigator.of(context).pop(),
      onSave: (drafts) async {
        final count = await ref
            .read(inventoryRepositoryProvider)
            .createBulkNodes(
              homeId: homeId,
              roomId: roomId,
              parentNodeId: parentNodeId,
              drafts: drafts,
              currency: currency,
            );
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
        child: SizedBox(width: 960, height: height, child: table),
      );
    }

    return Dialog.fullscreen(
      backgroundColor: AppColors.paper,
      child: SafeArea(child: table),
    );
  }
}

/// Spreadsheet of name / type / quantity / price for bulk create.
class BulkAddTable extends StatefulWidget {
  const BulkAddTable({
    super.key,
    required this.onClose,
    required this.onSave,
    this.currencyLabel = 'USD',
    this.initialRowCount = 6,
  });

  final VoidCallback onClose;
  final Future<void> Function(List<BulkNodeDraft> drafts) onSave;
  final String currencyLabel;
  final int initialRowCount;

  @override
  State<BulkAddTable> createState() => _BulkAddTableState();
}

class _BulkAddTableState extends State<BulkAddTable> {
  late final List<_BulkRow> _rows;
  bool _busy = false;
  final _hScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final count = widget.initialRowCount < 1 ? 1 : widget.initialRowCount;
    _rows = List<_BulkRow>.generate(count, (_) => _BulkRow());
    for (final row in _rows) {
      row.name.addListener(_onNameChanged);
    }
  }

  @override
  void dispose() {
    _hScroll.dispose();
    for (final row in _rows) {
      row.name.removeListener(_onNameChanged);
      row.dispose();
    }
    super.dispose();
  }

  void _onNameChanged() {
    if (mounted) setState(() {});
  }

  int get _namedCount {
    return _rows.where((row) => row.name.text.trim().isNotEmpty).length;
  }

  int get _selectedCount => _rows.where((row) => row.selected).length;

  bool? get _selectAllValue {
    if (_rows.isEmpty) return false;
    final selected = _selectedCount;
    if (selected == 0) return false;
    if (selected == _rows.length) return true;
    return null;
  }

  void _toggleSelectAll(bool? value) {
    final next = value ?? false;
    setState(() {
      for (final row in _rows) {
        row.selected = next;
      }
    });
  }

  void _applyType(InventoryTypeChoice type) {
    setState(() {
      final anyChecked = _rows.any((row) => row.selected);
      for (final row in _rows) {
        if (!anyChecked || row.selected) row.type = type;
      }
    });
  }

  void _addRow() {
    setState(() {
      final row = _BulkRow();
      row.name.addListener(_onNameChanged);
      _rows.add(row);
    });
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) {
      setState(() {
        _rows.first.name.clear();
        _rows.first.quantity.clear();
        _rows.first.price.clear();
        _rows.first.type = InventoryTypeChoice.item;
        _rows.first.selected = false;
      });
      return;
    }
    setState(() {
      final row = _rows.removeAt(index);
      row.name.removeListener(_onNameChanged);
      row.dispose();
    });
  }

  Future<void> _save() async {
    final drafts = namedBulkDrafts(_rows.map((row) => row.toDraft()));
    if (drafts.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.onSave(drafts);
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
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text('Add several', style: theme.textTheme.titleLarge),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: _busy ? null : widget.onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Check rows, then Set type to change several at once. '
              'With none checked, Set type updates every row. '
              'Blank names are skipped.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      key: const ValueKey('bulk-select-all'),
                      tristate: true,
                      value: _selectAllValue,
                      onChanged: _busy ? null : _toggleSelectAll,
                    ),
                    Text(
                      _selectedCount == 0
                          ? 'None selected'
                          : '$_selectedCount selected',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                Material(
                  color: AppColors.paperElevated,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: AppColors.line, width: 1.4),
                  ),
                  child: PopupMenuButton<InventoryTypeChoice>(
                    key: const ValueKey('bulk-type-apply'),
                    enabled: !_busy,
                    tooltip: _selectedCount == 0
                        ? 'Set type for all rows'
                        : 'Set type for selected rows',
                    onSelected: _applyType,
                    itemBuilder: (context) => [
                      for (final type in InventoryTypeChoice.values)
                        PopupMenuItem(value: type, child: Text(type.label)),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.category_outlined,
                            size: 18,
                            color: AppColors.mossDeep,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _selectedCount == 0
                                ? 'Set type for all'
                                : 'Set type of selected',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: AppColors.mossDeep,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: AppColors.mossDeep,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('bulk-add-row'),
                  onPressed: _busy ? null : _addRow,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add row'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const minWidth = 700.0;
                final width = constraints.maxWidth < minWidth
                    ? minWidth
                    : constraints.maxWidth;
                final table = SizedBox(
                  width: width,
                  child: Column(
                    children: [
                      _HeaderRow(currencyLabel: widget.currencyLabel),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _rows.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            return _DataRow(
                              row: _rows[index],
                              index: index,
                              enabled: !_busy,
                              autofocus: index == 0,
                              onToggle: () {
                                setState(() {
                                  _rows[index].selected =
                                      !_rows[index].selected;
                                });
                              },
                              onType: (type) {
                                setState(() => _rows[index].type = type);
                              },
                              onRemove: () => _removeRow(index),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
                if (constraints.maxWidth >= minWidth) return table;
                return Scrollbar(
                  controller: _hScroll,
                  thumbVisibility: true,
                  notificationPredicate: (notification) =>
                      notification.metrics.axis == Axis.horizontal,
                  child: SingleChildScrollView(
                    controller: _hScroll,
                    scrollDirection: Axis.horizontal,
                    child: table,
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Row(
              children: [
                TextButton(
                  onPressed: _busy ? null : widget.onClose,
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton(
                  key: const ValueKey('bulk-save'),
                  onPressed: _busy || _namedCount == 0 ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.moss,
                    minimumSize: const Size(140, 44),
                  ),
                  child: Text(_busy ? 'Adding…' : 'Add $_namedCount'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.currencyLabel});

  final String currencyLabel;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: AppColors.inkMuted,
      fontWeight: FontWeight.w600,
    );
    return ColoredBox(
      color: AppColors.paper,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        child: Row(
          children: [
            const SizedBox(width: 44),
            Expanded(flex: 4, child: Text('Name', style: style)),
            SizedBox(width: 148, child: Text('Type', style: style)),
            SizedBox(width: 84, child: Text('Qty', style: style)),
            SizedBox(
              width: 96,
              child: Text('Price ($currencyLabel)', style: style),
            ),
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.row,
    required this.index,
    required this.enabled,
    required this.autofocus,
    required this.onToggle,
    required this.onType,
    required this.onRemove,
  });

  final _BulkRow row;
  final int index;
  final bool enabled;
  final bool autofocus;
  final VoidCallback onToggle;
  final ValueChanged<InventoryTypeChoice> onType;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Checkbox(
              key: ValueKey('bulk-select-$index'),
              value: row.selected,
              onChanged: enabled ? (_) => onToggle() : null,
            ),
          ),
          Expanded(
            flex: 4,
            child: TextField(
              key: ValueKey('bulk-name-$index'),
              controller: row.name,
              enabled: enabled,
              autofocus: autofocus,
              textCapitalization: TextCapitalization.sentences,
              decoration: _cellDecoration(hint: 'Name'),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 148,
            child: InputDecorator(
              decoration: _cellDecoration(),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<InventoryTypeChoice>(
                  key: ValueKey('bulk-type-$index'),
                  // ignore: deprecated_member_use
                  value: row.type,
                  isDense: true,
                  isExpanded: true,
                  items: [
                    for (final type in InventoryTypeChoice.values)
                      DropdownMenuItem(value: type, child: Text(type.label)),
                  ],
                  onChanged: enabled
                      ? (type) {
                          if (type != null) onType(type);
                        }
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            child: TextField(
              key: ValueKey('bulk-qty-$index'),
              controller: row.quantity,
              enabled: enabled,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: _cellDecoration(hint: 'Qty'),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: TextField(
              key: ValueKey('bulk-price-$index'),
              controller: row.price,
              enabled: enabled,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: _cellDecoration(hint: 'Price'),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              key: ValueKey('bulk-remove-$index'),
              tooltip: 'Remove row',
              onPressed: enabled ? onRemove : null,
              icon: const Icon(Icons.close, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _cellDecoration({String? hint}) {
  return InputDecoration(
    isDense: true,
    hintText: hint,
    filled: true,
    fillColor: AppColors.paperElevated,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.moss, width: 1.4),
    ),
  );
}

class _BulkRow {
  _BulkRow()
    : name = TextEditingController(),
      quantity = TextEditingController(),
      price = TextEditingController();

  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController price;
  InventoryTypeChoice type = InventoryTypeChoice.item;
  bool selected = false;

  BulkNodeDraft toDraft() {
    return BulkNodeDraft(
      name: name.text,
      type: type,
      quantity: parseOptionalNumber(quantity.text),
      purchasePrice: parseOptionalNumber(price.text),
    );
  }

  void dispose() {
    name.dispose();
    quantity.dispose();
    price.dispose();
  }
}
