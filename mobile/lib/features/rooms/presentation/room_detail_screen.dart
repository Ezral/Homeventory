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

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(inventoryChildrenProvider(scope));
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
                      if (cover.signedUrl == null) {
                        return const SizedBox.shrink();
                      }
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
                if (canEdit && nodes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Long-press an object, then drop it onto a container.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                    ),
                  ),
                if (nodes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: parentNodeId == null
                          ? 'Empty room'
                          : 'Empty container',
                      message: canEdit
                          ? 'Add furniture, storage locations, or items. Items can also be containers.'
                          : 'Nothing stored here yet.',
                    ),
                  )
                else
                  for (var i = 0; i < nodes.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _InventoryDragTile(
                      homeId: homeId,
                      roomId: roomId,
                      scope: scope,
                      node: nodes[i],
                      thumbnailUrl: thumbs[nodes[i].id],
                      canEdit: canEdit,
                      subtitle: _subtitle(nodes[i]),
                      icon: _nodeIcon(nodes[i]),
                    ),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }

  String _subtitle(InventoryNode node) {
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

class _InventoryDragTile extends ConsumerWidget {
  const _InventoryDragTile({
    required this.homeId,
    required this.roomId,
    required this.scope,
    required this.node,
    required this.thumbnailUrl,
    required this.canEdit,
    required this.subtitle,
    required this.icon,
  });

  final String homeId;
  final String roomId;
  final InventoryScope scope;
  final InventoryNode node;
  final String? thumbnailUrl;
  final bool canEdit;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    SoftTile buildTile({VoidCallback? onTap}) {
      return SoftTile(
        leading: EntityThumbnail(
          imageUrl: thumbnailUrl,
          fallback: icon,
        ),
        title: node.name,
        subtitle: subtitle,
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
        onTap: onTap,
      );
    }

    void openNode() {
      if (node.isContainer) {
        context.push('/homes/$homeId/rooms/$roomId/nodes/${node.id}');
      } else {
        context.push(
          '/homes/$homeId/rooms/$roomId/nodes/${node.id}/details',
        );
      }
    }

    if (!canEdit) return buildTile(onTap: openNode);

    final feedback = Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: AppColors.paperElevated,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width - 48,
        ),
        child: SoftTile(
          leading: EntityThumbnail(
            imageUrl: thumbnailUrl,
            fallback: icon,
          ),
          title: node.name,
          subtitle: 'Drop onto a container',
          trailing: const Icon(Icons.open_with, color: AppColors.inkMuted),
        ),
      ),
    );

    final draggable = LongPressDraggable<InventoryNode>(
      data: node,
      hapticFeedbackOnStart: true,
      feedback: feedback,
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: buildTile(),
      ),
      child: buildTile(onTap: openNode),
    );

    if (!node.isContainer) return draggable;

    return DragTarget<InventoryNode>(
      onWillAcceptWithDetails: (details) {
        final dragged = details.data;
        return dragged.id != node.id && dragged.parentNodeId != node.id;
      },
      onAcceptWithDetails: (details) {
        _dropOntoContainer(
          context: context,
          ref: ref,
          dragged: details.data,
          container: node,
        );
      },
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hovering ? AppColors.mossDeep : Colors.transparent,
              width: 2,
            ),
            color: hovering
                ? AppColors.mossSoft.withValues(alpha: 0.55)
                : Colors.transparent,
          ),
          child: draggable,
        );
      },
    );
  }

  Future<void> _dropOntoContainer({
    required BuildContext context,
    required WidgetRef ref,
    required InventoryNode dragged,
    required InventoryNode container,
  }) async {
    if (dragged.id == container.id) return;
    if (dragged.parentNodeId == container.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${dragged.name} is already in ${container.name}')),
      );
      return;
    }

    try {
      await ref.read(inventoryRepositoryProvider).moveNode(
            nodeId: dragged.id,
            destinationRoomId: roomId,
            destinationParentId: container.id,
          );

      ref.invalidate(inventoryChildrenProvider(scope));
      ref.invalidate(
        inventoryChildrenProvider(
          InventoryScope(
            homeId: homeId,
            roomId: roomId,
            parentNodeId: container.id,
          ),
        ),
      );
      if (dragged.parentNodeId != null) {
        ref.invalidate(
          inventoryChildrenProvider(
            InventoryScope(
              homeId: homeId,
              roomId: roomId,
              parentNodeId: dragged.parentNodeId,
            ),
          ),
        );
      }
      ref.invalidate(inventoryNodeProvider(dragged.id));
      ref.invalidate(
        roomContainerDestinationsProvider((
          homeId: homeId,
          roomId: roomId,
          excludeNodeId: null,
        )),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moved ${dragged.name} into ${container.name}'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}
