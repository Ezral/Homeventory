import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../features/rooms/presentation/rooms_providers.dart';
import '../models/bulk_node_draft.dart';
import '../models/room.dart';
import 'app_widgets.dart';

Future<BulkPlacement?> showLocationPickerDialog({
  required BuildContext context,
  required String homeId,
  required BulkPlacement current,
}) {
  return showDialog<BulkPlacement>(
    context: context,
    builder: (context) =>
        _LocationPickerDialog(homeId: homeId, initial: current),
  );
}

class _LocationPickerDialog extends ConsumerStatefulWidget {
  const _LocationPickerDialog({required this.homeId, required this.initial});

  final String homeId;
  final BulkPlacement initial;

  @override
  ConsumerState<_LocationPickerDialog> createState() =>
      _LocationPickerDialogState();
}

class _LocationPickerDialogState extends ConsumerState<_LocationPickerDialog> {
  late String? _selectedRoomId;
  String? _browseParentId;
  final List<({String id, String name})> _crumbs = [];

  @override
  void initState() {
    super.initState();
    _selectedRoomId = widget.initial.roomId;
    _browseParentId = widget.initial.parentNodeId;
    if (_browseParentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreCrumbsIfNeeded();
      });
    }
  }

  InventoryScope? get _scope {
    final roomId = _selectedRoomId;
    if (roomId == null) return null;
    return InventoryScope(
      homeId: widget.homeId,
      roomId: roomId,
      parentNodeId: _browseParentId,
    );
  }

  String _label(List<Room> rooms) {
    final roomName = rooms
        .where((room) => room.id == _selectedRoomId)
        .map((room) => room.name)
        .firstOrNull;
    return formatBulkPlacementLabel(
      roomName: roomName ?? 'Room',
      containerNames: [for (final crumb in _crumbs) crumb.name],
    );
  }

  Future<void> _restoreCrumbsIfNeeded() async {
    final parentId = _browseParentId;
    if (parentId == null || _crumbs.isNotEmpty) return;
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final path = await repo.breadcrumbPath(await repo.getNode(parentId));
      if (!mounted) return;
      setState(() {
        _crumbs
          ..clear()
          ..addAll([for (final node in path) (id: node.id, name: node.name)]);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(roomsListProvider(widget.homeId));
    final scope = _scope;
    final childrenAsync = scope == null
        ? null
        : ref.watch(inventoryChildrenProvider(scope));

    return Dialog(
      backgroundColor: AppColors.paperElevated,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose location',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Pick a room, then browse into furniture or storage. New items are added here.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              const SectionLabel('Room'),
              const SizedBox(height: 8),
              roomsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => ErrorView(message: e.toString()),
                data: (rooms) {
                  return DropdownButtonFormField<String>(
                    key: const ValueKey('location-picker-room'),
                    // ignore: deprecated_member_use
                    value: _selectedRoomId,
                    decoration: const InputDecoration(labelText: 'Room'),
                    items: [
                      for (final room in rooms)
                        DropdownMenuItem(
                          value: room.id,
                          child: Text(room.name),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedRoomId = value;
                        _browseParentId = null;
                        _crumbs.clear();
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              const SectionLabel('Location'),
              const SizedBox(height: 8),
              if (_crumbs.isNotEmpty || _browseParentId != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => setState(() {
                          _browseParentId = null;
                          _crumbs.clear();
                        }),
                        child: const Text('Room root'),
                      ),
                      for (var i = 0; i < _crumbs.length; i++) ...[
                        const Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: AppColors.inkMuted,
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _crumbs.removeRange(i + 1, _crumbs.length);
                            _browseParentId = _crumbs[i].id;
                          }),
                          child: Text(_crumbs[i].name),
                        ),
                      ],
                    ],
                  ),
                ),
              Expanded(
                child: childrenAsync == null
                    ? const SizedBox.shrink()
                    : childrenAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => ErrorView(message: e.toString()),
                        data: (nodes) {
                          final containers = nodes
                              .where((n) => n.isContainer)
                              .toList();
                          if (containers.isEmpty) {
                            return Text(
                              _browseParentId == null
                                  ? 'No containers at room root. You can still add items here.'
                                  : 'No nested containers here. You can add items in this location.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            );
                          }
                          return ListView(
                            children: [
                              for (final container in containers)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: SoftTile(
                                    title: container.name,
                                    subtitle: container.kindLabel,
                                    onTap: () => setState(() {
                                      _crumbs.add((
                                        id: container.id,
                                        name: container.name,
                                      ));
                                      _browseParentId = container.id;
                                    }),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              roomsAsync.maybeWhen(
                data: (rooms) => FilledButton(
                  key: const ValueKey('location-picker-confirm'),
                  onPressed: _selectedRoomId == null
                      ? null
                      : () => Navigator.of(context).pop(
                          BulkPlacement(
                            roomId: _selectedRoomId!,
                            parentNodeId: _browseParentId,
                            label: _label(rooms),
                          ),
                        ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.moss,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: Text(
                    _browseParentId == null
                        ? 'Use room root'
                        : 'Use this location',
                  ),
                ),
                orElse: () => const SizedBox(height: 44),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
