import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/room.dart';
import '../../../shared/utils/image_pick.dart';
import '../../inventory/data/inventory_repository.dart';
import '../presentation/rooms_providers.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({
    super.key,
    required this.homeId,
    this.existingRoomId,
  });

  final String homeId;
  final String? existingRoomId;

  bool get isEditing => existingRoomId != null;

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
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
      final room =
          await ref.read(roomsRepositoryProvider).getRoom(widget.existingRoomId!);
      final images = await ref.read(inventoryRepositoryProvider).listImages(
            homeId: widget.homeId,
            entityType: 'ROOM',
            entityId: widget.existingRoomId!,
          );
      if (!mounted) return;
      setState(() {
        _name.text = room.name;
        _description.text = room.description ?? '';
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
      final repo = ref.read(roomsRepositoryProvider);
      final inventory = ref.read(inventoryRepositoryProvider);
      late Room room;
      if (widget.isEditing) {
        room = await repo.updateRoom(
          roomId: widget.existingRoomId!,
          name: _name.text,
          description: _description.text,
        );
        ref.invalidate(roomProvider(widget.existingRoomId!));
      } else {
        room = await repo.createRoom(
          homeId: widget.homeId,
          name: _name.text,
          description: _description.text,
        );
      }

      if (_pendingImage != null) {
        await inventory.uploadRoomImage(
          homeId: widget.homeId,
          roomId: room.id,
          bytes: _pendingImage!.bytes,
          mimeType: _pendingImage!.mimeType,
          extension: _pendingImage!.extension,
        );
      }

      ref.invalidate(roomsListProvider(widget.homeId));
      ref.invalidate(roomImagesProvider((homeId: widget.homeId, roomId: room.id)));
      if (!mounted) return;
      context.pop(room);
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
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit room' : 'New room'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
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
                      labelText: 'Room name',
                      hintText: 'Kitchen',
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
                          : (widget.isEditing ? 'Save changes' : 'Create room'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
