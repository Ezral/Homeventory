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
  static const _pendingNavKey = 'pending_nav';

  Future<String?> readActiveHomeId() => _storage.read(key: _activeHomeKey);

  Future<void> writeActiveHomeId(String homeId) =>
      _storage.write(key: _activeHomeKey, value: homeId);

  /// Path+query to open after Google SSO (e.g. invite join link).
  Future<String?> readPendingNav() => _storage.read(key: _pendingNavKey);

  Future<void> writePendingNav(String pathAndQuery) =>
      _storage.write(key: _pendingNavKey, value: pathAndQuery);

  Future<void> clearPendingNav() => _storage.delete(key: _pendingNavKey);

  Future<void> clearActiveHomeId() => _storage.delete(key: _activeHomeKey);

  Future<void> clearPrivateState() async {
    await _storage.delete(key: _activeHomeKey);
    await _storage.delete(key: _pendingNavKey);
  }
}

final localSessionStoreProvider = Provider<LocalSessionStore>((ref) {
  return LocalSessionStore(ref.watch(secureStorageProvider));
});
