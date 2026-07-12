import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/profile.dart';
import '../../../shared/providers/supabase_provider.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    client: ref.watch(supabaseClientProvider),
    config: ref.watch(appConfigProvider),
    localSessionStore: ref.watch(localSessionStoreProvider),
  );
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentSessionProvider = Provider<Session?>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.maybeWhen(
    data: (state) => state.session,
    orElse: () => ref.watch(authRepositoryProvider).currentSession,
  );
});

final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return null;
  return ref.watch(authRepositoryProvider).fetchCurrentProfile();
});
