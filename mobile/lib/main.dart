import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/router.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'shared/providers/supabase_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();

  if (config.isConfigured) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
      ],
      child: const HomeventoryApp(),
    ),
  );
}

class HomeventoryApp extends ConsumerWidget {
  const HomeventoryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final router = config.isConfigured
        ? ref.watch(routerProvider)
        : null;

    // When Supabase is not initialized, avoid watching providers that touch
    // Supabase.instance. Use a dedicated router for setup only.
    if (!config.isConfigured) {
      return MaterialApp(
        title: 'Homeventory',
        debugShowCheckedModeBanner: false,
        theme: buildHomeventoryTheme(),
        home: const SetupRequiredScreen(),
      );
    }

    return MaterialApp.router(
      title: 'Homeventory',
      debugShowCheckedModeBanner: false,
      theme: buildHomeventoryTheme(),
      routerConfig: router!,
    );
  }
}
