import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/enums.dart';
import '../../../shared/models/inventory_node.dart';
import '../../../shared/utils/image_pick.dart';
import '../../homes/presentation/homes_providers.dart';
import '../../rooms/presentation/rooms_providers.dart';

class CreateNodeScreen extends ConsumerStatefulWidget {
  const CreateNodeScreen({
    super.key,
    required this.homeId,
    required this.roomId,
    this.parentNodeId,
    this.existingNodeId,
  });

  final String homeId;
  final String roomId;
  final String? parentNodeId;
  final String? existingNodeId;

  bool get isEditing => existingNodeId != null;

  @override
  ConsumerState<CreateNodeScreen> createState() => _CreateNodeScreenState();
}

class _CreateNodeScreenState extends ConsumerState<CreateNodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _quantity = TextEditingController();
  final _unit = TextEditingController();
  final _minQuantity = TextEditingController();
  final _price = TextEditingController();
  final _currency = TextEditingController(text: 'USD');
  final _brand = TextEditingController();

  InventoryNodeKind _kind = InventoryNodeKind.item;
  ItemCategory _category = ItemCategory.misc;
  bool _isContainer = false;
  bool _isMobileContainer = false;
  DateTime? _purchaseDate;
  DateTime? _expirationDate;
  bool _busy = false;
  bool _loadingExisting = false;
  InventoryNode? _existing;
  PickedImageBytes? _pendingImage;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadingExisting = true;
      _loadExisting();
    } else {
      _loadDefaultCurrency();
    }
  }

  Future<void> _loadDefaultCurrency() async {
    try {
      final home = await ref.read(homeProvider(widget.homeId).future);
      if (!mounted) return;
      if (_currency.text.trim().isEmpty || _currency.text == 'USD') {
        setState(() => _currency.text = home.defaultCurrency);
      }
    } catch (_) {}
  }

  Future<void> _loadExisting() async {
    try {
      final node = await ref
          .read(inventoryRepositoryProvider)
          .getNode(widget.existingNodeId!);
      if (!mounted) return;
      setState(() {
        _existing = node;
        _kind = node.nodeKind;
        _category = node.itemCategory ?? ItemCategory.misc;
        _isContainer = node.isContainer;
        _isMobileContainer = node.isMobileContainer;
        _name.text = node.name;
        _description.text = node.description ?? '';
        _quantity.text = node.quantity?.toString() ?? '';
        _unit.text = node.quantityUnit ?? '';
        _minQuantity.text = node.minimumQuantity?.toString() ?? '';
        _price.text = node.purchasePrice?.toString() ?? '';
        _currency.text = node.currency ?? 'USD';
        _brand.text = node.brand ?? '';
        _purchaseDate = node.purchaseDate;
        _expirationDate = node.expirationDate;
        _loadingExisting = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingExisting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _quantity.dispose();
    _unit.dispose();
    _minQuantity.dispose();
    _price.dispose();
    _currency.dispose();
    _brand.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool purchase}) async {
    final initial = purchase
        ? (_purchaseDate ?? DateTime.now())
        : (_expirationDate ?? DateTime.now().add(const Duration(days: 30)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (purchase) {
        _purchaseDate = picked;
      } else {
        _expirationDate = picked;
      }
    });
  }

  Future<void> _pickImage() async {
    final picked = await pickEntityImage(context);
    if (picked == null || !mounted) return;
    setState(() => _pendingImage = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final qty = _quantity.text.trim().isEmpty
          ? null
          : double.tryParse(_quantity.text.trim());
      final minQty = _minQuantity.text.trim().isEmpty
          ? null
          : double.tryParse(_minQuantity.text.trim());
      final price = _price.text.trim().isEmpty
          ? null
          : double.tryParse(_price.text.trim());
      final treatAsContainer = _kind != InventoryNodeKind.item ||
          _isContainer ||
          _isMobileContainer;

      final repo = ref.read(inventoryRepositoryProvider);
      late InventoryNode node;
      if (widget.isEditing) {
        node = await repo.updateNode(
          nodeId: widget.existingNodeId!,
          name: _name.text,
          description: _description.text,
          isContainer: treatAsContainer,
          isMobileContainer: _isMobileContainer,
          itemCategory: _kind == InventoryNodeKind.item ? _category : null,
          quantity: qty,
          quantityUnit: _unit.text,
          minimumQuantity: minQty,
          purchasePrice: price,
          currency: _currency.text,
          purchaseDate: _purchaseDate,
          expirationDate: _expirationDate,
          brand: _brand.text,
        );
      } else {
        node = await repo.createNode(
          homeId: widget.homeId,
          roomId: widget.roomId,
          parentNodeId: widget.parentNodeId,
          nodeKind: _kind,
          name: _name.text,
          description: _description.text,
          isContainer: treatAsContainer,
          isMobileContainer: _isMobileContainer,
          itemCategory: _kind == InventoryNodeKind.item ? _category : null,
          quantity: qty,
          quantityUnit: _unit.text,
          minimumQuantity: minQty,
          purchasePrice: price,
          currency: _currency.text,
          purchaseDate: _purchaseDate,
          expirationDate: _expirationDate,
          brand: _brand.text,
        );
      }

      if (_pendingImage != null) {
        await repo.uploadNodeImage(
          homeId: widget.homeId,
          nodeId: node.id,
          bytes: _pendingImage!.bytes,
          mimeType: _pendingImage!.mimeType,
          extension: _pendingImage!.extension,
        );
      }

      ref.invalidate(
        inventoryChildrenProvider(
          InventoryScope(
            homeId: widget.homeId,
            roomId: widget.roomId,
            parentNodeId: widget.parentNodeId ?? _existing?.parentNodeId,
          ),
        ),
      );
      if (widget.isEditing) {
        ref.invalidate(inventoryNodeProvider(widget.existingNodeId!));
        ref.invalidate(
          nodeImagesProvider(
            (homeId: widget.homeId, nodeId: widget.existingNodeId!),
          ),
        );
      }

      if (!mounted) return;
      // Always pop so the previous page remains on the stack.
      context.pop(node);
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
    final dateFormat = DateFormat.yMMMd();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit inventory' : 'Add to inventory'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loadingExisting
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (!widget.isEditing)
                    DropdownButtonFormField<InventoryNodeKind>(
                      // ignore: deprecated_member_use
                      value: _kind,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: InventoryNodeKind.values
                          .map(
                            (k) => DropdownMenuItem(
                              value: k,
                              child: Text(k.label),
                            ),
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
                    )
                  else
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'Type'),
                      child: Text(_kind.label),
                    ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Name is required'
                        : null,
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
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.label),
                            ),
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
                            decoration:
                                const InputDecoration(labelText: 'Quantity'),
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
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _minQuantity,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Minimum quantity (optional)',
                      ),
                    ),
                  ] else
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Is a container'),
                      value: true,
                      onChanged: null,
                    ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _brand,
                    decoration: const InputDecoration(
                      labelText: 'Brand (optional)',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _price,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Purchase price',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 100,
                        child: TextFormField(
                          controller: _currency,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Currency',
                            hintText: 'USD',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Purchase date'),
                    subtitle: Text(
                      _purchaseDate == null
                          ? 'Not set'
                          : dateFormat.format(_purchaseDate!),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_purchaseDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () =>
                                setState(() => _purchaseDate = null),
                          ),
                        IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () => _pickDate(purchase: true),
                        ),
                      ],
                    ),
                  ),
                  if (_kind == InventoryNodeKind.item)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Expiration date'),
                      subtitle: Text(
                        _expirationDate == null
                            ? 'Not set'
                            : dateFormat.format(_expirationDate!),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_expirationDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () =>
                                  setState(() => _expirationDate = null),
                            ),
                          IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () => _pickDate(purchase: false),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text('Photo', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_pendingImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _pendingImage!.bytes,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Text(
                      widget.isEditing
                          ? 'Add another photo from details, or replace here.'
                          : 'Optional photo for this object.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickImage,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(
                      _pendingImage == null ? 'Add photo' : 'Replace photo',
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(
                      _busy
                          ? 'Saving…'
                          : (widget.isEditing ? 'Save changes' : 'Save'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
