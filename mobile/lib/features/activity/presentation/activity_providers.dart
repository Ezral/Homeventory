import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/activity_event.dart';
import '../../../shared/providers/supabase_provider.dart';
import '../data/activity_repository.dart';

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository(ref.watch(supabaseClientProvider));
});

final homeActivityProvider = FutureProvider.autoDispose
    .family<List<ActivityEvent>, String>((ref, homeId) {
      return ref.watch(activityRepositoryProvider).listForHome(homeId);
    });
