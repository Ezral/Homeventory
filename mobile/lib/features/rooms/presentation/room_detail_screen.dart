import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/inventory_node.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/entity_thumbnail.dart';
import '../../../shared/widgets/home_invite_sheet.dart';
import '../../../shared/widgets/home_shell_bottom_nav.dart';
import '../../../shared/widgets/user_menu_button.dart';
import '../../homes/presentation/homes_providers.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../trips/presentation/trips_providers.dart';
import 'rooms_providers.dart';

class RoomDetailScreen extends ConsumerWidget {
  const RoomDetailScreen({
    super.key,
    required this.homeId,
    required this.roomId,
    this.parentNodeId,
  });

  final String homeId;
  final String roomId;
  final String? parentNodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomProvider(roomId));
    final homeAsync = ref.watch(homeProvider(homeId));
    final scope = InventoryScope(
      homeId: homeId,
      roomId: roomId,
      parentNodeId: parentNodeId,
    );
    final childrenAsync = ref.watch(inventoryChildrenProvider(scope));
    final parentAsync = parentNodeId == null
        ? null
        : ref.watch(inventoryNodeProvider(parentNodeId!));
    final roomImagesAsync = parentNodeId == null
        ? ref.watch(roomImagesProvider((homeId: homeId, roomId: roomId)))
        : null;

    final canEdit = homeAsync.maybeWhen(
      data: (h) => h.myRole?.canEditInventory ?? false,
      orElse: () => false,
    );
    final canInvite = homeAsync.maybeWhen(
      data: (h) => h.myRole?.canManageMembers ?? false,
      orElse: () => false,
    );

    final title = parentAsync?.maybeWhen(
          data: (n) => n.name,
          orElse: () => null,
        ) ??
        roomAsync.maybeWhen(data: (r) => r.name, orElse: () => 'Room');

    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'Room'),
        actions: [
          if (canEdit && parentNodeId == null)
            IconButton(
              tooltip: 'Edit room',
              onPressed: () async {
                await context.push('/homes/$homeId/rooms/$roomId/edit');
                ref.invalidate(roomProvider(roomId));
                ref.invalidate(roomsListProvider(homeId));
                ref.invalidate(
                  roomImagesProvider((homeId: homeId, roomId: roomId)),
                );
              },
              icon: const Icon(Icons.edit_outlined),
            ),
          if (canEdit && parentNodeId != null)
            IconButton(
              tooltip: 'Edit',
              onPressed: () async {
                await context.push(
                  '/homes/$homeId/rooms/$roomId/nodes/$parentNodeId/edit',
                );
                ref.invalidate(inventoryNodeProvider(parentNodeId!));
                ref.invalidate(inventoryChildrenProvider(scope));
              },
              icon: const Icon(Icons.edit_outlined),
            ),
          if (parentNodeId != null)
            IconButton(
              tooltip: 'Details',
              onPressed: () => context.push(
                '/homes/$homeId/rooms/$roomId/nodes/$parentNodeId/details',
              ),
              icon: const Icon(Icons.info_outline),
            ),
          const UserMenuButton(),
        ],
      ),
      floatingActionButton: null,
      bottomNavigationBar: HomeShellBottomNav(
        selectedIndex: 2,
        addLabel: 'Add object',
        onSelect: (index) async {
          switch (index) {
            case 0:
              await context.push('/homes/$homeId/search');
            case 1:
              await context.push('/homes/$homeId/trips');
            case 2:
              context.go('/homes/$homeId');
            case 3:
              if (canInvite) {
                await showHomeInviteSheet(
                  context: context,
                  ref: ref,
                  homeId: homeId,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Only owners and admins can invite members.',
                    ),
                  ),
                );
              }
            case 4:
              if (!canEdit) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('You do not have permission to add objects.'),
                  ),
                );
                return;
              }
              await context.push(
                parentNodeId == null
                    ? '/homes/$homeId/rooms/$roomId/nodes/new'
                    : '/homes/$homeId/rooms/$roomId/nodes/new?parent=$parentNodeId',
              );
              ref.invalidate(inventoryChildrenProvider(scope));
          }
        },
      ),
      body: childrenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(inventoryChildrenProvider(scope)),
        ),
        data: (nodes) {
          final idsKey = nodes.map((n) => n.id).join(',');
          final thumbsAsync = ref.watch(
            entityThumbnailsProvider(
              (
                homeId: homeId,
                entityType: 'INVENTORY_NODE',
                idsKey: idsKey,
              ),
            ),
          );
          final thumbs = thumbsAsync.maybeWhen(
            data: (m) => m,
            orElse: () => const <String, String>{},
          );
          final packedMap = ref
              .watch(homePackedNodesProvider(homeId))
              .maybeWhen(
                data: (m) => m,
                orElse: () => const <String, PackedNodeInfo>{},
              );

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(inventoryChildrenProvider(scope));
              ref.invalidate(homePackedNodesProvider(homeId));
              if (parentNodeId == null) {
                ref.invalidate(
                  roomImagesProvider((homeId: homeId, roomId: roomId)),
                );
              }
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                if (parentNodeId == null && roomImagesAsync != null)
                  roomImagesAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (images) {
                      if (images.isEmpty) return const SizedBox.shrink();
                      final cover = images.first;
                      if (cover.signedUrl == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.network(
                              cover.signedUrl!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                if (nodes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title:
                          parentNodeId == null ? 'Empty room' : 'Empty container',
                      message: canEdit
                          ? 'Add furniture, storage locations, or items. Items can also be containers.'
                          : 'Nothing stored here yet.',
                    ),
                  )
                else
                  ...[
                    for (var i = 0; i < nodes.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      Builder(
                        builder: (context) {
                          final node = nodes[i];
                          final packed = packedMap[node.id];
                          return SoftTile(
                            leading: EntityThumbnail(
                              imageUrl: thumbs[node.id],
                              fallback: _nodeIcon(node),
                            ),
                            title: node.name,
                            subtitle: _subtitle(node, packed),
                            dimmed: packed != null,
                            trailing: node.isContainer
                                ? IconButton(
                                    tooltip: 'Details',
                                    icon: const Icon(Icons.info_outline),
                                    color: AppColors.inkMuted,
                                    onPressed: () => context.push(
                                      '/homes/$homeId/rooms/$roomId/nodes/${node.id}/details',
                                    ),
                                  )
                                : null,
                            onTap: () {
                              if (node.isContainer) {
                                context.push(
                                  '/homes/$homeId/rooms/$roomId/nodes/${node.id}',
                                );
                              } else {
                                context.push(
                                  '/homes/$homeId/rooms/$roomId/nodes/${node.id}/details',
                                );
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ],
              ],
            ),
          );
        },
      ),
    );
  }

  String _subtitle(InventoryNode node, PackedNodeInfo? packed) {
    final parts = <String>[node.kindLabel];
    if (node.itemCategory != null) parts.add(node.itemCategory!.label);
    if (node.quantity != null) {
      parts.add(
        [
          _formatQty(node.quantity!),
          if (node.quantityUnit != null) node.quantityUnit!,
        ].join(' '),
      );
    }
    if (node.purchasePrice != null) {
      parts.add(
        '${node.currency ?? ''} ${_formatQty(node.purchasePrice!)}'.trim(),
      );
    }
    if (packed != null) {
      parts.add(
        'Packed · ${packed.tripName}'
        '${packed.packedIntoName != null ? ' (${packed.packedIntoName})' : ''}',
      );
    }
    return parts.join(' · ');
  }

  String _formatQty(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  IconData _nodeIcon(InventoryNode node) {
    return switch (node.nodeKind) {
      InventoryNodeKind.furniture => Icons.weekend_outlined,
      InventoryNodeKind.storageLocation => Icons.grid_view_outlined,
      InventoryNodeKind.item =>
        node.isContainer ? Icons.work_outline : Icons.inventory_2_outlined,
    };
  }
}
