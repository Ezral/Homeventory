import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/invite_token.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/home.dart';
import '../../../shared/providers/supabase_provider.dart';

class HomesRepository {
  HomesRepository({
    required this.client,
    required this.localSessionStore,
  });

  final SupabaseClient client;
  final LocalSessionStore localSessionStore;

  String get _userId {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('Not signed in');
    return id;
  }

  Future<List<Home>> listMyHomes() async {
    final memberships = await client
        .from('home_members')
        .select('home_id, role, status, homes(*)')
        .eq('user_id', _userId)
        .eq('status', MembershipStatus.active.dbValue);

    final homes = <Home>[];
    for (final row in memberships as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final homeJson = Map<String, dynamic>.from(map['homes'] as Map);
      if (homeJson['archived_at'] != null) continue;
      homes.add(
        Home.fromJson(
          homeJson,
          myRole: HomeRole.fromDb(map['role'] as String),
        ),
      );
    }
    homes.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return homes;
  }

  Future<Home> createHome({
    required String name,
    String? description,
    String? addressText,
  }) async {
    final inserted = await client
        .from('homes')
        .insert({
          'name': name.trim(),
          'description': description?.trim().isEmpty == true
              ? null
              : description?.trim(),
          'address_text':
              addressText?.trim().isEmpty == true ? null : addressText?.trim(),
          'created_by_user_id': _userId,
        })
        .select()
        .single();

    final home = Home.fromJson(
      Map<String, dynamic>.from(inserted),
      myRole: HomeRole.owner,
    );
    await localSessionStore.writeActiveHomeId(home.id);
    return home;
  }

  Future<Home> getHome(String homeId) async {
    final row = await client.from('homes').select().eq('id', homeId).single();
    final role =
        await client.rpc('home_role_of', params: {'p_home_id': homeId});
    return Home.fromJson(
      Map<String, dynamic>.from(row),
      myRole: role == null ? null : HomeRole.fromDb(role as String),
    );
  }

  Future<void> archiveHome(String homeId) async {
    await client.from('homes').update({
      'archived_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', homeId);
  }

  /// Returns the plaintext token once so the UI can show link/QR/code.
  Future<CreatedInvitation> createInvitation({
    required String homeId,
    HomeRole role = HomeRole.editor,
    int expiresHours = 168,
  }) async {
    if (role == HomeRole.owner) {
      throw ArgumentError('Invitations cannot grant OWNER.');
    }
    final token = generateInviteToken();
    final shortCode = generateShortCode();
    final row = await client.rpc(
      'create_invitation',
      params: {
        'p_home_id': homeId,
        'p_role': role.dbValue,
        'p_token': token,
        'p_short_code': shortCode,
        'p_expires_in_hours': expiresHours,
      },
    );

    final map = row is Map ? Map<String, dynamic>.from(row) : null;
    return CreatedInvitation(
      invitationId: map?['id'] as String?,
      token: token,
      shortCode: shortCode,
      role: role,
    );
  }

  Future<String> acceptInvitation(String tokenOrCode) async {
    final input = tokenOrCode.trim();
    final row = await client.rpc(
      'accept_invitation',
      params: {'p_token': input},
    );
    final map = Map<String, dynamic>.from(row as Map);
    final id = map['home_id'] as String;
    await localSessionStore.writeActiveHomeId(id);
    return id;
  }

  Future<void> removeMember({
    required String homeId,
    required String userId,
  }) async {
    await client.rpc(
      'remove_home_member',
      params: {
        'p_home_id': homeId,
        'p_user_id': userId,
      },
    );
  }

  Future<void> leaveHome(String homeId) async {
    await client.rpc('leave_home', params: {'p_home_id': homeId});
    final active = await localSessionStore.readActiveHomeId();
    if (active == homeId) {
      await localSessionStore.clearPrivateState();
    }
  }

  Future<List<HomeMember>> listMembers(String homeId) async {
    final rows = await client
        .from('home_members')
        .select('id, home_id, user_id, role, status, joined_at, profiles(display_name, email)')
        .eq('home_id', homeId)
        .eq('status', MembershipStatus.active.dbValue)
        .order('created_at');

    return (rows as List)
        .map(
          (row) => HomeMember.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<String?> readActiveHomeId() => localSessionStore.readActiveHomeId();

  Future<void> setActiveHomeId(String homeId) =>
      localSessionStore.writeActiveHomeId(homeId);
}

class CreatedInvitation {
  const CreatedInvitation({
    required this.invitationId,
    required this.token,
    required this.shortCode,
    required this.role,
  });

  final String? invitationId;
  final String token;
  final String shortCode;
  final HomeRole role;
}
