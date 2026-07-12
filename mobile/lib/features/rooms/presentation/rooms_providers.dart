import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/inventory_node.dart';
import '../../../shared/models/room.dart';
import '../../../shared/providers/supabase_provider.dart';
import '../../inventory/data/inventory_repository.dart';
import '../data/rooms_repository.dart';

final roomsRepositoryProvider = Provider<RoomsRepository>((ref) {
  return RoomsRepository(ref.watch(supabaseClientProvider));
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.watch(supabaseClientProvider));
});

final roomsListProvider =
    FutureProvider.autoDispose.family<List<Room>, String>((ref, homeId) {
  return ref.watch(roomsRepositoryProvider).listRooms(homeId);
});

final roomProvider =
    FutureProvider.autoDispose.family<Room, String>((ref, roomId) {
  return ref.watch(roomsRepositoryProvider).getRoom(roomId);
});

class InventoryScope {
  const InventoryScope({
    required this.homeId,
    required this.roomId,
    this.parentNodeId,
  });

  final String homeId;
  final String roomId;
  final String? parentNodeId;

  @override
  bool operator ==(Object other) =>
      other is InventoryScope &&
      other.homeId == homeId &&
      other.roomId == roomId &&
      other.parentNodeId == parentNodeId;

  @override
  int get hashCode => Object.hash(homeId, roomId, parentNodeId);
}

final inventoryChildrenProvider = FutureProvider.autoDispose
    .family<List<InventoryNode>, InventoryScope>((ref, scope) {
  return ref.watch(inventoryRepositoryProvider).listChildren(
        homeId: scope.homeId,
        roomId: scope.roomId,
        parentNodeId: scope.parentNodeId,
      );
});

final inventoryNodeProvider =
    FutureProvider.autoDispose.family<InventoryNode, String>((ref, nodeId) {
  return ref.watch(inventoryRepositoryProvider).getNode(nodeId);
});

final inventorySearchProvider = FutureProvider.autoDispose
    .family<List<InventoryNode>, ({String homeId, String query})>((ref, args) {
  return ref.watch(inventoryRepositoryProvider).search(
        homeId: args.homeId,
        query: args.query,
      );
});
