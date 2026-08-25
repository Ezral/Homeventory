import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/enums.dart';
import '../../../shared/models/inventory_node.dart';
import '../../../shared/utils/image_pick.dart';
import '../../../shared/widgets/entity_photo_gallery.dart';
import '../../../shared/widgets/image_ingest_region.dart';
import '../../homes/presentation/homes_providers.dart';
import '../../inventory/data/inventory_repository.dart';
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
  final _capacity = TextEditingController();
  final _price = TextEditingController();
  final _currency = TextEditingController(text: 'USD');
  final _brand = TextEditingController();
  final _weight = TextEditingController();
  final _weightUnit = TextEditingController(text: 'g');

  InventoryTypeChoice _type = InventoryTypeChoice.item;
  ItemCategory _category = ItemCategory.misc;
  bool _isContainer = false;
  bool _isMobileContainer = false;
  bool _isDispenser = false;
  DispenserMode _dispenserMode = DispenserMode.single;
  bool _isDispensable = false;
  ConsumableForm? _consumableForm;
  DateTime? _purchaseDate;
  DateTime? _expirationDate;
  bool _busy = false;
  bool _loadingExisting = false;
  InventoryNode? _existing;
  PickedImageBytes? _pendingImage;
  List<EntityImage> _existingImages = const [];
  final List<EntityImage> _imagesToDelete = [];

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
      final repo = ref.read(inventoryRepositoryProvider);
      final node = await repo.getNode(widget.existingNodeId!);
      final images = await repo.listImages(
        homeId: widget.homeId,
        entityType: 'INVENTORY_NODE',
        entityId: widget.existingNodeId!,
      );
      if (!mounted) return;
      setState(() {
        _existing = node;
        _type = InventoryTypeChoice.fromNode(
          nodeKind: node.nodeKind,
          itemCategory: node.itemCategory,
        );
        _category = node.itemCategory ?? ItemCategory.misc;
        _isContainer = node.isContainer;
        _isMobileContainer = node.isMobileContainer;
        _isDispenser = node.isDispenser;
        _dispenserMode = node.effectiveDispenserMode;
        _isDispensable = node.isDispensable;
        _consumableForm = node.consumableForm;
        _name.text = node.name;
        _description.text = node.description ?? '';
        _quantity.text = node.quantity?.toString() ?? '';
        _unit.text = node.quantityUnit ?? '';
        _minQuantity.text = node.minimumQuantity?.toString() ?? '';
        _capacity.text = node.capacity?.toString() ?? '';
        _price.text = node.purchasePrice?.toString() ?? '';
        _currency.text = node.currency ?? 'USD';
        _brand.text = node.brand ?? '';
        _weight.text = node.weight?.toString() ?? '';
        _weightUnit.text = node.weightUnit ?? 'g';
        _purchaseDate = node.purchaseDate;
        _expirationDate = node.expirationDate;
        _existingImages = images;
        _loadingExisting = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingExisting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
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
    _capacity.dispose();
    _price.dispose();
    _currency.dispose();
    _brand.dispose();
    _weight.dispose();
    _weightUnit.dispose();
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

  void _setType(InventoryTypeChoice next) {
    setState(() {
      _type = next;
      if (next.isContainerKind) {
        _isMobileContainer = false;
        _isContainer = true;
        _isDispenser = false;
        _isDispensable = false;
      }
      if (next == InventoryTypeChoice.clothing) {
        _category = ItemCategory.clothing;
      } else if (next == InventoryTypeChoice.item &&
          _category == ItemCategory.clothing) {
        _category = ItemCategory.misc;
      }
    });
  }

  Widget _typeField() {
    return DropdownButtonFormField<InventoryTypeChoice>(
      // ignore: deprecated_member_use
      value: _type,
      decoration: InputDecoration(
        labelText: 'Type',
        helperText: widget.isEditing
            ? 'You can change type later, including Item to Furniture or Clothing.'
            : null,
      ),
      items: [
        for (final type in InventoryTypeChoice.values)
          DropdownMenuItem(value: type, child: Text(type.label)),
      ],
      onChanged: (v) {
        if (v != null) _setType(v);
      },
    );
  }

  Future<void> _submit({bool addAnother = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final qty = _quantity.text.trim().isEmpty
          ? null
          : double.tryParse(_quantity.text.trim());
      final minQty = _minQuantity.text.trim().isEmpty
          ? null
          : double.tryParse(_minQuantity.text.trim());
      final capacity = _capacity.text.trim().isEmpty || !_isDispenser
          ? null
          : double.tryParse(_capacity.text.trim());
      final price = _price.text.trim().isEmpty
          ? null
          : double.tryParse(_price.text.trim());
      final weight = _weight.text.trim().isEmpty
          ? null
          : double.tryParse(_weight.text.trim());
      final treatAsContainer =
          !_type.isItemLike || _isContainer || _isMobileContainer;
      final itemCategory = _type.isItemLike
          ? (_type == InventoryTypeChoice.clothing
                ? ItemCategory.clothing
                : _category)
          : null;
      final isMobile = _type.isItemLike && _isMobileContainer;
      final isDispenser = _type.isItemLike && _isDispenser;
      final isDispensable = _type.isItemLike && _isDispensable;

      final repo = ref.read(inventoryRepositoryProvider);
      late InventoryNode node;
      if (widget.isEditing) {
        node = await repo.updateNode(
          nodeId: widget.existingNodeId!,
          name: _name.text,
          nodeKind: _type.nodeKind,
          description: _description.text,
          isContainer: treatAsContainer,
          isMobileContainer: isMobile,
          isDispenser: isDispenser,
          dispenserMode: isDispenser ? _dispenserMode : null,
          isDispensable: isDispensable,
          consumableForm: isDispensable ? _consumableForm : null,
          capacity: capacity,
          itemCategory: itemCategory,
          quantity: qty,
          quantityUnit: _unit.text,
          minimumQuantity: minQty,
          purchasePrice: price,
          currency: _currency.text,
          purchaseDate: _purchaseDate,
          expirationDate: _expirationDate,
          brand: _brand.text,
          weight: weight,
          weightUnit: _weightUnit.text,
        );
      } else {
        node = await repo.createNode(
          homeId: widget.homeId,
          roomId: widget.roomId,
          parentNodeId: widget.parentNodeId,
          nodeKind: _type.nodeKind,
          name: _name.text,
          description: _description.text,
          isContainer: treatAsContainer,
          isMobileContainer: isMobile,
          isDispenser: isDispenser,
          dispenserMode: isDispenser ? _dispenserMode : null,
          isDispensable: isDispensable,
          consumableForm: isDispensable ? _consumableForm : null,
          capacity: capacity,
          itemCategory: itemCategory,
          quantity: qty,
          quantityUnit: _unit.text,
          minimumQuantity: minQty,
          purchasePrice: price,
          currency: _currency.text,
          purchaseDate: _purchaseDate,
          expirationDate: _expirationDate,
          brand: _brand.text,
          weight: weight,
          weightUnit: _weightUnit.text,
        );
      }

      if (_imagesToDelete.isNotEmpty) {
        for (final image in _imagesToDelete) {
          await repo.deleteImage(image);
        }
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
        invalidateNodeImageCaches(
          ref,
          homeId: widget.homeId,
          nodeId: widget.existingNodeId!,
        );
      }

      if (!mounted) return;
      if (addAnother && !widget.isEditing) {
        _name.clear();
        _description.clear();
        setState(() {
          _pendingImage = null;
          _imagesToDelete.clear();
          _existingImages = const [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${node.name}. Add another.')),
        );
        return;
      }
      // Always pop so the previous page remains on the stack.
      context.pop(node);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
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
                  _typeField(),
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
                  if (_type.isItemLike) ...[
                    if (_type == InventoryTypeChoice.item) ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<ItemCategory>(
                        // ignore: deprecated_member_use
                        value: ItemCategory.itemFormValues.contains(_category)
                            ? _category
                            : ItemCategory.misc,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: ItemCategory.itemFormValues
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
                    ],
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
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Is dispenser'),
                      subtitle: const Text(
                        'Tracks a refillable capacity, such as soap or oil.',
                      ),
                      value: _isDispenser,
                      onChanged: (v) => setState(() {
                        _isDispenser = v;
                        if (v) _isDispensable = false;
                      }),
                    ),
                    if (_isDispenser) ...[
                      DropdownButtonFormField<DispenserMode>(
                        // ignore: deprecated_member_use
                        value: _dispenserMode,
                        decoration: const InputDecoration(
                          labelText: 'Dispenser mode',
                        ),
                        items: [
                          for (final mode in DispenserMode.values)
                            DropdownMenuItem(
                              value: mode,
                              child: Text(mode.label),
                            ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _dispenserMode = v);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Dispensable product'),
                      subtitle: const Text(
                        'Can be linked into a dispenser slot.',
                      ),
                      value: _isDispensable,
                      onChanged: _isDispenser
                          ? null
                          : (v) => setState(() => _isDispensable = v),
                    ),
                    if (_isDispensable) ...[
                      DropdownButtonFormField<ConsumableForm>(
                        // ignore: deprecated_member_use
                        value: _consumableForm,
                        decoration: const InputDecoration(
                          labelText: 'Consumable form (optional)',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Not set'),
                          ),
                          for (final form in ConsumableForm.values)
                            DropdownMenuItem(
                              value: form,
                              child: Text(form.label),
                            ),
                        ],
                        onChanged: (v) => setState(() => _consumableForm = v),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _quantity,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _unit,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              hintText: 'pcs, ml, g, CC',
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_isDispenser) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _capacity,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: _dispenserMode == DispenserMode.multi
                              ? 'Capacity per chamber (optional)'
                              : 'Capacity (optional)',
                          helperText: _dispenserMode == DispenserMode.multi
                              ? 'Each product slot gets this capacity (e.g. 300 CC × 2 gels).'
                              : 'Max fill for this dispenser.',
                        ),
                      ),
                    ],
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
                          controller: _weight,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Weight (optional)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 100,
                        child: TextFormField(
                          controller: _weightUnit,
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                            hintText: 'g',
                          ),
                        ),
                      ),
                    ],
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
                  if (_type.isItemLike)
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
                  ImageIngestRegion(
                    enabled: !_busy,
                    showHint: true,
                    onImages: (images) {
                      if (images.isEmpty) return;
                      setState(() => _pendingImage = images.last);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Photo',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (_existingImages.isNotEmpty) ...[
                          EntityPhotoGallery(
                            images: [
                              for (final image in _existingImages)
                                GalleryPhoto(
                                  id: image.id,
                                  url: image.signedUrl,
                                ),
                            ],
                            canEdit: true,
                            confirmBeforeDelete: false,
                            onDelete: _busy
                                ? null
                                : (id) async {
                                    final image = _existingImages.firstWhere(
                                      (item) => item.id == id,
                                    );
                                    setState(() {
                                      _imagesToDelete.add(image);
                                      _existingImages = _existingImages
                                          .where((item) => item.id != id)
                                          .toList();
                                    });
                                  },
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (_pendingImage != null)
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  _pendingImage!.bytes,
                                  height: 160,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Material(
                                  color: Colors.black54,
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    tooltip: 'Delete photo',
                                    iconSize: 18,
                                    padding: const EdgeInsets.all(8),
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                    color: Colors.white,
                                    icon: const Icon(Icons.close),
                                    onPressed: _busy
                                        ? null
                                        : () => setState(
                                            () => _pendingImage = null,
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else if (_existingImages.isEmpty)
                          Text(
                            widget.isEditing
                                ? 'No photos. Add one here or from details.'
                                : 'Optional photo for this object.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        if (_imagesToDelete.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Removed photos are deleted when you save.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _pickImage,
                              icon: const Icon(Icons.add_a_photo_outlined),
                              label: Text(
                                _pendingImage == null
                                    ? 'Add photo'
                                    : 'Replace photo',
                              ),
                            ),
                            if (_pendingImage != null)
                              TextButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () =>
                                          setState(() => _pendingImage = null),
                                icon: const Icon(Icons.hide_image_outlined),
                                label: const Text('Remove photo'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _busy ? null : () => _submit(),
                    child: Text(
                      _busy
                          ? 'Saving…'
                          : (widget.isEditing ? 'Save changes' : 'Save'),
                    ),
                  ),
                  if (!widget.isEditing) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _submit(addAnother: true),
                      child: const Text('Save & add another'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
