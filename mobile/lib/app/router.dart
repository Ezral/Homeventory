import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_providers.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/homes/presentation/create_home_screen.dart';
import '../features/homes/presentation/home_detail_screen.dart';
import '../features/homes/presentation/homes_screen.dart';
import '../features/homes/presentation/join_home_screen.dart';
import '../features/inventory/presentation/barcode_scan_screen.dart';
import '../features/inventory/presentation/create_node_screen.dart';
import '../features/inventory/presentation/move_node_screen.dart';
import '../features/inventory/presentation/node_detail_screen.dart';
import '../features/rooms/presentation/create_room_screen.dart';
import '../features/rooms/presentation/room_detail_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/trips/presentation/trip_detail_screen.dart';
import '../features/trips/presentation/trips_list_screen.dart';
import '../shared/providers/supabase_provider.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authRefresh = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, _) {
    authRefresh.value++;
  });
  ref.onDispose(authRefresh.dispose);

  final config = ref.watch(appConfigProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      if (!config.isConfigured) {
        return state.matchedLocation == '/setup' ? null : '/setup';
      }

      final session = ref.read(authRepositoryProvider).currentSession;
      final loggingIn = state.matchedLocation == '/sign-in';
      final isSetup = state.matchedLocation == '/setup';

      if (session == null && !loggingIn) return '/sign-in';
      if (session != null && (loggingIn || isSetup)) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/setup',
        builder: (context, state) => const SetupRequiredScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(path: '/', builder: (context, state) => const HomesScreen()),
      GoRoute(
        path: '/homes/new',
        builder: (context, state) => const CreateHomeScreen(),
      ),
      GoRoute(
        path: '/homes/join',
        builder: (context, state) => const JoinHomeScreen(),
      ),
      GoRoute(
        path: '/homes/:homeId/edit',
        builder: (context, state) => CreateHomeScreen(
          existingHomeId: state.pathParameters['homeId'],
        ),
      ),
      GoRoute(
        path: '/homes/:homeId',
        builder: (context, state) =>
            HomeDetailScreen(homeId: state.pathParameters['homeId']!),
      ),
      GoRoute(
        path: '/homes/:homeId/search',
        builder: (context, state) =>
            SearchScreen(homeId: state.pathParameters['homeId']!),
      ),
      GoRoute(
        path: '/homes/:homeId/trips',
        builder: (context, state) =>
            TripsListScreen(homeId: state.pathParameters['homeId']!),
      ),
      GoRoute(
        path: '/homes/:homeId/trips/:tripId',
        builder: (context, state) => TripDetailScreen(
          homeId: state.pathParameters['homeId']!,
          tripId: state.pathParameters['tripId']!,
        ),
      ),
      GoRoute(
        path: '/homes/:homeId/rooms/new',
        builder: (context, state) =>
            CreateRoomScreen(homeId: state.pathParameters['homeId']!),
      ),
      GoRoute(
        path: '/homes/:homeId/rooms/:roomId/edit',
        builder: (context, state) => CreateRoomScreen(
          homeId: state.pathParameters['homeId']!,
          existingRoomId: state.pathParameters['roomId'],
        ),
      ),
      GoRoute(
        path: '/homes/:homeId/rooms/:roomId',
        builder: (context, state) => RoomDetailScreen(
          homeId: state.pathParameters['homeId']!,
          roomId: state.pathParameters['roomId']!,
        ),
      ),
      GoRoute(
        path: '/homes/:homeId/rooms/:roomId/nodes/new',
        builder: (context, state) => CreateNodeScreen(
          homeId: state.pathParameters['homeId']!,
          roomId: state.pathParameters['roomId']!,
          parentNodeId: state.uri.queryParameters['parent'],
        ),
      ),
      GoRoute(
        path: '/homes/:homeId/rooms/:roomId/nodes/:nodeId/edit',
        builder: (context, state) => CreateNodeScreen(
          homeId: state.pathParameters['homeId']!,
          roomId: state.pathParameters['roomId']!,
          existingNodeId: state.pathParameters['nodeId'],
        ),
      ),
      GoRoute(
        path: '/homes/:homeId/rooms/:roomId/nodes/:nodeId/move',
        builder: (context, state) => MoveNodeScreen(
          homeId: state.pathParameters['homeId']!,
          roomId: state.pathParameters['roomId']!,
          nodeId: state.pathParameters['nodeId']!,
        ),
      ),
      GoRoute(
        path: '/homes/:homeId/rooms/:roomId/nodes/:nodeId',
        builder: (context, state) => RoomDetailScreen(
          homeId: state.pathParameters['homeId']!,
          roomId: state.pathParameters['roomId']!,
          parentNodeId: state.pathParameters['nodeId'],
        ),
      ),
      GoRoute(
        path: '/homes/:homeId/rooms/:roomId/nodes/:nodeId/details',
        builder: (context, state) => NodeDetailScreen(
          homeId: state.pathParameters['homeId']!,
          roomId: state.pathParameters['roomId']!,
          nodeId: state.pathParameters['nodeId']!,
        ),
      ),
      GoRoute(
        path: '/homes/:homeId/scan-barcode',
        builder: (context, state) => const BarcodeScanScreen(),
      ),
    ],
  );
});

class SetupRequiredScreen extends ConsumerWidget {
  const SetupRequiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text(
                'Homeventory',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Connect Supabase to start.',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                'Run the app with dart-defines for your project URL and anon key. '
                'Never ship the service-role key in the APK.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              SelectableText(
                'flutter run \\\n'
                '  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \\\n'
                '  --dart-define=SUPABASE_ANON_KEY=eyJ... \\\n'
                '  --dart-define=GOOGLE_WEB_CLIENT_ID=....apps.googleusercontent.com',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.5,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
