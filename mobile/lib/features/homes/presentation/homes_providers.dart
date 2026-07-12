import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/home.dart';
import '../../../shared/providers/supabase_provider.dart';
import '../data/homes_repository.dart';

final homesRepositoryProvider = Provider<HomesRepository>((ref) {
  return HomesRepository(
    client: ref.watch(supabaseClientProvider),
    localSessionStore: ref.watch(localSessionStoreProvider),
  );
});

final homesListProvider = FutureProvider.autoDispose<List<Home>>((ref) {
  return ref.watch(homesRepositoryProvider).listMyHomes();
});

final homeProvider =
    FutureProvider.autoDispose.family<Home, String>((ref, homeId) {
  return ref.watch(homesRepositoryProvider).getHome(homeId);
});

final homeMembersProvider =
    FutureProvider.autoDispose.family<List<HomeMember>, String>((ref, homeId) {
  return ref.watch(homesRepositoryProvider).listMembers(homeId);
});

final activeHomeIdProvider =
    AsyncNotifierProvider<ActiveHomeIdController, String?>(
  ActiveHomeIdController.new,
);

class ActiveHomeIdController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() {
    return ref.read(homesRepositoryProvider).readActiveHomeId();
  }

  Future<void> setActive(String homeId) async {
    await ref.read(homesRepositoryProvider).setActiveHomeId(homeId);
    state = AsyncValue.data(homeId);
  }
}
