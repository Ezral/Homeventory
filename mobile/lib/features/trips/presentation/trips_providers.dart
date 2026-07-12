import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/inventory_node.dart';
import '../../../shared/providers/supabase_provider.dart';
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
