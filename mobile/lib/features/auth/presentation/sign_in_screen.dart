import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/supabase_provider.dart';
import 'auth_providers.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      final config = ref.read(appConfigProvider);
      if (kIsWeb || !config.hasGoogleClient) {
        await repo.signInWithGoogleOAuth();
      } else {
        await repo.signInWithGoogle();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F2ED),
              AppColors.paper,
              Color(0xFFDCE8E2),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                Text(
                  'Homeventory',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: AppColors.mossDeep,
                        fontSize: 42,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'A searchable digital map of everything in your home.',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Find it. Track it. Use it. Refill it. Pack it. Put it back.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                ),
                const Spacer(flex: 3),
                if (!config.isConfigured)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE6C88A)),
                    ),
                    child: Text(
                      'Supabase is not configured. Launch with '
                      '--dart-define=SUPABASE_URL=... and '
                      '--dart-define=SUPABASE_ANON_KEY=...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.ink,
                          ),
                    ),
                  ),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.danger,
                        ),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  onPressed: (_busy || !config.isConfigured) ? null : _signIn,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(_busy ? 'Signing in…' : 'Continue with Google'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Google SSO only. Profiles are created automatically on first sign-in.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
