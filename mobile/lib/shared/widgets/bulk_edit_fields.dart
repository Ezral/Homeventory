import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../models/bulk_node_draft.dart';
import '../models/enums.dart';

/// Type / quantity / price / brand / weight editor that prefills shared
/// values from the current selection. Mixed fields stay blank with a hint.
class BulkEditFields extends StatefulWidget {
  const BulkEditFields({
    super.key,
    required this.initial,
    required this.onApply,
    required this.applyLabel,
    this.enabled = true,
    this.currencyLabel = 'USD',
  });

  final SharedBulkValues initial;
  final void Function(BulkNodePatch patch) onApply;
  final String applyLabel;
  final bool enabled;
  final String currencyLabel;

  @override
  State<BulkEditFields> createState() => _BulkEditFieldsState();
}

class _BulkEditFieldsState extends State<BulkEditFields> {
  late InventoryTypeChoice? _type;
  late final TextEditingController _quantity;
  late final TextEditingController _price;
  late final TextEditingController _brand;
  late final TextEditingController _weight;

  @override
  void initState() {
    super.initState();
    _type = widget.initial.typeMixed ? null : widget.initial.type;
    _quantity = TextEditingController(
      text: widget.initial.quantityMixed
          ? ''
          : (formatOptionalNumber(widget.initial.quantity) ?? ''),
    );
    _price = TextEditingController(
      text: widget.initial.priceMixed
          ? ''
          : (formatOptionalNumber(widget.initial.purchasePrice) ?? ''),
    );
    _brand = TextEditingController(
      text: widget.initial.brandMixed ? '' : (widget.initial.brand ?? ''),
    );
    _weight = TextEditingController(
      text: widget.initial.weightMixed
          ? ''
          : (formatOptionalNumber(widget.initial.weight) ?? ''),
    );
  }

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    _brand.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _apply() {
    widget.onApply(
      BulkNodePatch(
        type: _type,
        applyQuantity: _quantity.text.trim().isNotEmpty,
        quantity: parseOptionalNumber(_quantity.text),
        applyPrice: _price.text.trim().isNotEmpty,
        purchasePrice: parseOptionalNumber(_price.text),
        applyBrand: _brand.text.trim().isNotEmpty,
        brand: _brand.text.trim(),
        applyWeight: _weight.text.trim().isNotEmpty,
        weight: parseOptionalNumber(_weight.text),
        weightUnit: _weight.text.trim().isNotEmpty ? 'g' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 148,
          child: InputDecorator(
            decoration: _decoration(
              label: 'Type',
              hint: widget.initial.typeMixed ? 'Mixed' : null,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<InventoryTypeChoice>(
                key: const ValueKey('bulk-edit-type'),
                // ignore: deprecated_member_use
                value: _type,
                isDense: true,
                isExpanded: true,
                hint: Text(
                  widget.initial.typeMixed ? 'Mixed' : 'Type',
                  style: theme.textTheme.bodyMedium,
                ),
                items: [
                  for (final type in InventoryTypeChoice.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: widget.enabled
                    ? (type) => setState(() => _type = type)
                    : null,
              ),
            ),
          ),
        ),
        SizedBox(
          width: 96,
          child: TextField(
            key: const ValueKey('bulk-edit-qty'),
            controller: _quantity,
            enabled: widget.enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: _decoration(
              label: 'Quantity',
              hint: widget.initial.quantityMixed ? 'Mixed' : 'Qty',
            ),
          ),
        ),
        SizedBox(
          width: 108,
          child: TextField(
            key: const ValueKey('bulk-edit-price'),
            controller: _price,
            enabled: widget.enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: _decoration(
              label: 'Price (${widget.currencyLabel})',
              hint: widget.initial.priceMixed ? 'Mixed' : 'Price',
            ),
          ),
        ),
        SizedBox(
          width: 132,
          child: TextField(
            key: const ValueKey('bulk-edit-brand'),
            controller: _brand,
            enabled: widget.enabled,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoration(
              label: 'Brand',
              hint: widget.initial.brandMixed ? 'Mixed' : 'Brand',
            ),
          ),
        ),
        SizedBox(
          width: 96,
          child: TextField(
            key: const ValueKey('bulk-edit-weight'),
            controller: _weight,
            enabled: widget.enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: _decoration(
              label: 'Weight (g)',
              hint: widget.initial.weightMixed ? 'Mixed' : 'Weight',
            ),
          ),
        ),
        FilledButton(
          key: const ValueKey('bulk-edit-apply'),
          onPressed: widget.enabled ? _apply : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.moss,
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          child: Text(widget.applyLabel),
        ),
      ],
    );
  }
}

InputDecoration _decoration({required String label, String? hint}) {
  return InputDecoration(
    isDense: true,
    labelText: label,
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
