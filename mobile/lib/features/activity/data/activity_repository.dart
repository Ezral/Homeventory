import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/activity_event.dart';

class ActivityRepository {
  ActivityRepository(this._client);

  final SupabaseClient _client;

  Future<List<ActivityEvent>> listForHome(
    String homeId, {
    int limit = 100,
  }) async {
    final rows = await _client
        .from('activity_events')
        .select()
        .eq('home_id', homeId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => ActivityEvent.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }
}
