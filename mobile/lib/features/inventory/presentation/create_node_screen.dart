import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/enums.dart';
import '../../rooms/presentation/rooms_providers.dart';

class CreateNodeScreen extends ConsumerStatefulWidget {
  const CreateNodeScreen({
    super.key,
    required this.homeId,
    required this.roomId,
    this.parentNodeId,
  });

  final String homeId;
  final String roomId;
  final String? parentNodeId;

  @override
  ConsumerState<CreateNodeScreen> createState() => _CreateNodeScreenState();
}

class _CreateNodeScreenState extends ConsumerState<CreateNodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _quantity = TextEditingController();
  final _unit = TextEditingController();

  InventoryNodeKind _kind = InventoryNodeKind.item;
  ItemCategory _category = ItemCategory.misc;
  bool _isContainer = false;
  bool _isMobileContainer = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _quantity.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final qty = _quantity.text.trim().isEmpty
          ? null
          : double.tryParse(_quantity.text.trim());
      final treatAsContainer = _kind != InventoryNodeKind.item ||
          _isContainer ||
          _isMobileContainer;
      final node = await ref.read(inventoryRepositoryProvider).createNode(
            homeId: widget.homeId,
            roomId: widget.roomId,
            parentNodeId: widget.parentNodeId,
            nodeKind: _kind,
            name: _name.text,
            description: _description.text,
            isContainer: treatAsContainer,
            isMobileContainer: _isMobileContainer,
            itemCategory:
                _kind == InventoryNodeKind.item ? _category : null,
            quantity: qty,
            quantityUnit:
                _unit.text.trim().isEmpty ? null : _unit.text.trim(),
          );

      ref.invalidate(
        inventoryChildrenProvider(
          InventoryScope(
            homeId: widget.homeId,
            roomId: widget.roomId,
            parentNodeId: widget.parentNodeId,
          ),
        ),
      );

      if (!mounted) return;
      if (node.isContainer) {
        context.go(
          '/homes/${widget.homeId}/rooms/${widget.roomId}/nodes/${node.id}',
        );
      } else {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add to inventory')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<InventoryNodeKind>(
              // ignore: deprecated_member_use
              value: _kind,
              decoration: const InputDecoration(labelText: 'Type'),
              items: InventoryNodeKind.values
                  .map(
                    (k) => DropdownMenuItem(value: k, child: Text(k.label)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _kind = v;
                  if (v != InventoryNodeKind.item) {
                    _isMobileContainer = false;
                    _isContainer = true;
                  }
                });
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
            ),
            if (_kind == InventoryNodeKind.item) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<ItemCategory>(
                // ignore: deprecated_member_use
                value: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: ItemCategory.values
                    .map(
                      (c) =>
                          DropdownMenuItem(value: c, child: Text(c.label)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _category = v);
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Also a container'),
                subtitle: const Text(
                  'Suitcases, bags, and boxes can hold other items.',
                ),
                value: _isContainer || _isMobileContainer,
                onChanged: (v) => setState(() {
                  _isContainer = v;
                  if (!v) _isMobileContainer = false;
                }),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mobile container'),
                subtitle: const Text('Can be assigned to trips later.'),
                value: _isMobileContainer,
                onChanged: (v) => setState(() {
                  _isMobileContainer = v;
                  if (v) _isContainer = true;
                }),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantity,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        hintText: 'pcs',
                      ),
                    ),
                  ),
                ],
              ),
            ] else
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Is a container'),
                value: true,
                onChanged: null,
              ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
