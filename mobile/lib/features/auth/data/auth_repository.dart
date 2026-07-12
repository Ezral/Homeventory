import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/providers/supabase_provider.dart';

class AuthRepository {
  AuthRepository({
    required this.client,
    required this.config,
    required this.localSessionStore,
    GoogleSignIn? googleSignIn,
  }) : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final SupabaseClient client;
  final AppConfig config;
  final LocalSessionStore localSessionStore;
  final GoogleSignIn _googleSignIn;
  bool _googleInitialized = false;

  Session? get currentSession => client.auth.currentSession;
  User? get currentUser => client.auth.currentUser;

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await _googleSignIn.initialize(
      serverClientId:
          config.hasGoogleClient ? config.googleWebClientId : null,
    );
    _googleInitialized = true;
  }

  Future<Profile?> fetchCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final row = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) return null;
    return Profile.fromJson(Map<String, dynamic>.from(row));
  }

  /// Browser OAuth via Supabase (recommended on Android; uses Web client ID/secret).
  Future<bool> signInWithGoogleOAuth() {
    const redirectTo = kIsWeb
        ? null
        : 'com.homeventory.homeventory://login-callback/';
    return client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
  }

  Future<AuthResponse> signInWithGoogle() async {
    if (!_googleSignIn.supportsAuthenticate()) {
      throw UnsupportedError(
        'Native Google authenticate() is not supported on this platform. '
        'Use OAuth instead.',
      );
    }
    if (!config.hasGoogleClient && !kIsWeb) {
      throw StateError(
        'GOOGLE_WEB_CLIENT_ID is required for native Google Sign-In.',
      );
    }

    await _ensureGoogleInitialized();
    final googleUser = await _googleSignIn.authenticate(
      scopeHint: const ['email', 'profile'],
    );

    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('Google sign-in did not return an ID token.');
    }

    // Access token is optional for Supabase Google ID-token sign-in.
    String? accessToken;
    try {
      final authz = await googleUser.authorizationClient.authorizationForScopes(
        const ['email', 'profile'],
      );
      accessToken = authz?.accessToken;
    } catch (_) {
      accessToken = null;
    }

    return client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<void> signOut() async {
    try {
      await _ensureGoogleInitialized();
      await _googleSignIn.signOut();
    } catch (_) {
      // Google session may already be cleared.
    }
    await localSessionStore.clearPrivateState();
    await client.auth.signOut();
  }
}
