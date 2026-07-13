import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/inventory_node.dart';
import '../../../shared/providers/supabase_provider.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../rooms/presentation/rooms_providers.dart';
import '../data/trips_repository.dart';

final tripsRepositoryProvider = Provider<TripsRepository>((ref) {
  return TripsRepository(ref.watch(supabaseClientProvider));
});

final tripsListProvider = FutureProvider.autoDispose.family<List<Trip>, String>(
  (ref, homeId) {
    return ref.watch(tripsRepositoryProvider).listTrips(homeId);
  },
);

final tripProvider = FutureProvider.autoDispose.family<Trip, String>((
  ref,
  tripId,
) {
  return ref.watch(tripsRepositoryProvider).getTrip(tripId);
});

final tripContainersProvider = FutureProvider.autoDispose
    .family<List<TripContainer>, String>((ref, tripId) {
      return ref.watch(tripsRepositoryProvider).listTripContainers(tripId);
    });

final tripItemsProvider = FutureProvider.autoDispose
    .family<List<TripItem>, String>((ref, tripId) {
      return ref.watch(tripsRepositoryProvider).listTripItems(tripId);
    });

final mobileContainersProvider = FutureProvider.autoDispose
    .family<List<InventoryNode>, String>((ref, homeId) {
      return ref.watch(tripsRepositoryProvider).listMobileContainers(homeId);
    });

final nodeDescendantsProvider = FutureProvider.autoDispose
    .family<List<DescendantNode>, String>((ref, rootNodeId) {
      return ref.watch(inventoryRepositoryProvider).listDescendants(rootNodeId);
    });

final roomPackableNodesProvider = FutureProvider.autoDispose
    .family<List<DescendantNode>, String>((ref, roomId) {
      return ref
          .watch(inventoryRepositoryProvider)
          .listRoomPackableNodes(roomId);
    });

final homePackedNodesProvider = FutureProvider.autoDispose
    .family<Map<String, PackedNodeInfo>, String>((ref, homeId) {
      return ref.watch(inventoryRepositoryProvider).listHomePackedNodes(homeId);
    });
