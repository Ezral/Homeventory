import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/utils/image_pick.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../rooms/presentation/rooms_providers.dart';
import 'homes_providers.dart';

const _kCurrencies = ['USD', 'THB', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'SGD', 'IDR', 'MYR'];

const _kTimezones = [
  'UTC',
  'Asia/Bangkok',
  'Asia/Jakarta',
  'Asia/Singapore',
  'Asia/Tokyo',
  'Asia/Seoul',
  'Australia/Sydney',
  'Europe/London',
  'Europe/Paris',
  'America/New_York',
  'America/Los_Angeles',
];

class CreateHomeScreen extends ConsumerStatefulWidget {
  const CreateHomeScreen({super.key, this.existingHomeId});

  final String? existingHomeId;

  bool get isEditing => existingHomeId != null;

  @override
  ConsumerState<CreateHomeScreen> createState() => _CreateHomeScreenState();
}

class _CreateHomeScreenState extends ConsumerState<CreateHomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  String _timezone = 'UTC';
  String _currency = 'USD';
  bool _busy = false;
  bool _loading = false;
  PickedImageBytes? _pendingImage;
  List<EntityImage> _existingImages = const [];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final home =
          await ref.read(homesRepositoryProvider).getHome(widget.existingHomeId!);
      final images = await ref.read(inventoryRepositoryProvider).listImages(
            homeId: widget.existingHomeId!,
            entityType: 'HOME',
            entityId: widget.existingHomeId!,
          );
      if (!mounted) return;
      setState(() {
        _name.text = home.name;
        _description.text = home.description ?? '';
        _address.text = home.addressText ?? '';
        _timezone = home.timezone;
        _currency = home.defaultCurrency.toUpperCase();
        _existingImages = images;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
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
    _address.dispose();
    super.dispose();
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
      final homes = ref.read(homesRepositoryProvider);
      final inventory = ref.read(inventoryRepositoryProvider);
      late final String homeId;

      if (widget.isEditing) {
        final home = await homes.updateHome(
          homeId: widget.existingHomeId!,
          name: _name.text,
          description: _description.text,
          addressText: _address.text,
          timezone: _timezone,
          defaultCurrency: _currency,
        );
        homeId = home.id;
        ref.invalidate(homeProvider(homeId));
      } else {
        final home = await homes.createHome(
          name: _name.text,
          description: _description.text,
          addressText: _address.text,
          timezone: _timezone,
          defaultCurrency: _currency,
        );
        homeId = home.id;
      }

      if (_pendingImage != null) {
        await inventory.uploadHomeImage(
          homeId: homeId,
          bytes: _pendingImage!.bytes,
          mimeType: _pendingImage!.mimeType,
          extension: _pendingImage!.extension,
        );
      }

      ref.invalidate(homesListProvider);
      ref.invalidate(homeImagesProvider(homeId));
      ref.invalidate(homeProvider(homeId));
      if (!mounted) return;
      if (widget.isEditing) {
        context.pop(true);
      } else {
        context.go('/homes/$homeId');
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
    final timezoneItems = {
      ..._kTimezones,
      if (!_kTimezones.contains(_timezone)) _timezone,
    }.toList()
      ..sort();
    final currencyItems = {
      ..._kCurrencies,
      if (!_kCurrencies.contains(_currency)) _currency,
    }.toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit home' : 'New home'),
        leading: widget.isEditing
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Home name',
                      hintText: 'Bangkok Apartment',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Name is required'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _description,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _address,
                    decoration: const InputDecoration(
                      labelText: 'Address (optional)',
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: timezoneItems.contains(_timezone)
                        ? _timezone
                        : timezoneItems.first,
                    decoration: const InputDecoration(labelText: 'Timezone'),
                    items: [
                      for (final tz in timezoneItems)
                        DropdownMenuItem(value: tz, child: Text(tz)),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) {
                            if (v == null) return;
                            setState(() => _timezone = v);
                          },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: currencyItems.contains(_currency)
                        ? _currency
                        : currencyItems.first,
                    decoration:
                        const InputDecoration(labelText: 'Default currency'),
                    items: [
                      for (final c in currencyItems)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) {
                            if (v == null) return;
                            setState(() => _currency = v);
                          },
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
                  else if (_existingImages.isNotEmpty &&
                      _existingImages.first.signedUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _existingImages.first.signedUrl!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Text(
                      'No photo yet.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickImage,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(
                      _pendingImage != null || _existingImages.isNotEmpty
                          ? 'Replace photo'
                          : 'Add photo',
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(
                      _busy
                          ? 'Saving…'
                          : (widget.isEditing ? 'Save changes' : 'Create home'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
