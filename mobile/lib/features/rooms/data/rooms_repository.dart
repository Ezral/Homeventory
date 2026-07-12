import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/room.dart';

class RoomsRepository {
  RoomsRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not signed in');
    return id;
  }

  Future<List<Room>> listRooms(String homeId) async {
    final rows = await _client
        .from('rooms')
        .select()
        .eq('home_id', homeId)
        .isFilter('archived_at', null)
        .order('sort_order')
        .order('name');

    return (rows as List)
        .map((r) => Room.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<Room> createRoom({
    required String homeId,
    required String name,
    String? description,
    int sortOrder = 0,
  }) async {
    final inserted = await _client
        .from('rooms')
        .insert({
          'home_id': homeId,
          'name': name.trim(),
          'description':
              description?.trim().isEmpty == true ? null : description?.trim(),
          'sort_order': sortOrder,
          'created_by_user_id': _userId,
        })
        .select()
        .single();

    return Room.fromJson(Map<String, dynamic>.from(inserted));
  }

  Future<Room> updateRoom({
    required String roomId,
    required String name,
    String? description,
  }) async {
    final updated = await _client
        .from('rooms')
        .update({
          'name': name.trim(),
          'description':
              description?.trim().isEmpty == true ? null : description?.trim(),
        })
        .eq('id', roomId)
        .select()
        .single();
    return Room.fromJson(Map<String, dynamic>.from(updated));
  }

  Future<Room> getRoom(String roomId) async {
    final row =
        await _client.from('rooms').select().eq('id', roomId).single();
    return Room.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> archiveRoom(String roomId) async {
    await _client.from('rooms').update({
      'archived_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', roomId);
  }
}
