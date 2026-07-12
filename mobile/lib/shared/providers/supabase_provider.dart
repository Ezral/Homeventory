import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Cleared on logout so private local state does not linger.
class LocalSessionStore {
  LocalSessionStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _activeHomeKey = 'active_home_id';

  Future<String?> readActiveHomeId() => _storage.read(key: _activeHomeKey);

  Future<void> writeActiveHomeId(String homeId) =>
      _storage.write(key: _activeHomeKey, value: homeId);

  Future<void> clearPrivateState() async {
    await _storage.delete(key: _activeHomeKey);
  }
}

final localSessionStoreProvider = Provider<LocalSessionStore>((ref) {
  return LocalSessionStore(ref.watch(secureStorageProvider));
});
