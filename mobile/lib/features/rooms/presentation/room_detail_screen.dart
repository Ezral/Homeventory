import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/inventory_node.dart';
import '../../../shared/widgets/app_widgets.dart';
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

    final canEdit = homeAsync.maybeWhen(
      data: (h) => h.myRole?.canEditInventory ?? false,
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
          if (canEdit)
            IconButton(
              tooltip: 'Add item',
              onPressed: () => context.push(
                parentNodeId == null
                    ? '/homes/$homeId/rooms/$roomId/nodes/new'
                    : '/homes/$homeId/rooms/$roomId/nodes/new?parent=$parentNodeId',
              ),
              icon: const Icon(Icons.add_box_outlined),
            ),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => context.push(
                parentNodeId == null
                    ? '/homes/$homeId/rooms/$roomId/nodes/new'
                    : '/homes/$homeId/rooms/$roomId/nodes/new?parent=$parentNodeId',
              ),
              backgroundColor: AppColors.moss,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
      body: childrenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(inventoryChildrenProvider(scope)),
        ),
        data: (nodes) {
          if (nodes.isEmpty) {
            return EmptyState(
              icon: Icons.inventory_2_outlined,
              title: parentNodeId == null ? 'Empty room' : 'Empty container',
              message: canEdit
                  ? 'Add furniture, storage locations, or items. Items can also be containers.'
                  : 'Nothing stored here yet.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(inventoryChildrenProvider(scope)),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              itemCount: nodes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final node = nodes[index];
                return SoftTile(
                  leading: _NodeIcon(node: node),
                  title: node.name,
                  subtitle: _subtitle(node),
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
    return parts.join(' · ');
  }

  String _formatQty(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }
}

class _NodeIcon extends StatelessWidget {
  const _NodeIcon({required this.node});

  final InventoryNode node;

  @override
  Widget build(BuildContext context) {
    final icon = switch (node.nodeKind) {
      InventoryNodeKind.furniture => Icons.weekend_outlined,
      InventoryNodeKind.storageLocation => Icons.grid_view_outlined,
      InventoryNodeKind.item =>
        node.isContainer ? Icons.work_outline : Icons.inventory_2_outlined,
    };
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.mossSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppColors.mossDeep),
    );
  }
}
