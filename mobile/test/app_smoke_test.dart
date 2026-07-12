import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeventory/core/config/app_config.dart';
import 'package:homeventory/main.dart';
import 'package:homeventory/shared/providers/supabase_provider.dart';

void main() {
  testWidgets('shows setup screen when Supabase is not configured',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              supabaseUrl: '',
              supabaseAnonKey: '',
              googleWebClientId: '',
            ),
          ),
        ],
        child: const HomeventoryApp(),
      ),
    );

    expect(find.text('Homeventory'), findsOneWidget);
    expect(find.textContaining('Connect Supabase'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
  });
}
