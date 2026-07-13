import 'package:flutter_test/flutter_test.dart';

import 'package:homeventory/core/config/app_config.dart';
import 'package:homeventory/core/utils/invite_token.dart';
import 'package:homeventory/shared/models/enums.dart';
import 'package:homeventory/shared/models/home.dart';
import 'package:homeventory/shared/models/inventory_node.dart';
import 'package:homeventory/shared/models/profile.dart';
import 'package:homeventory/shared/models/room.dart';

void main() {
  group('AppConfig', () {
    test('isConfigured requires url and anon key', () {
      const empty = AppConfig(
        supabaseUrl: '',
        supabaseAnonKey: '',
        googleWebClientId: '',
      );
      expect(empty.isConfigured, isFalse);

      const ready = AppConfig(
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon',
        googleWebClientId: '',
      );
      expect(ready.isConfigured, isTrue);
      expect(ready.hasGoogleClient, isFalse);
    });
  });

  group('invite tokens', () {
    test('generateInviteToken length and alphabet', () {
      final token = generateInviteToken(length: 40);
      expect(token.length, 40);
      expect(RegExp(r'^[A-Za-z0-9]+$').hasMatch(token), isTrue);
    });

    test('sha256Hex is stable and hex-encoded', () {
      final digest = sha256Hex('homeventory');
      expect(digest.length, 64);
      expect(RegExp(r'^[a-f0-9]+$').hasMatch(digest), isTrue);
      expect(digest, sha256Hex('homeventory'));
      expect(sha256Hex('a'), isNot(sha256Hex('b')));
    });

    test('short codes avoid ambiguous characters', () {
      final code = generateShortCode();
      expect(code.length, 8);
      expect(code.contains('I'), isFalse);
      expect(code.contains('O'), isFalse);
      expect(code.contains('0'), isFalse);
      expect(code.contains('1'), isFalse);
    });
  });

  group('enums', () {
    test('HomeRole permissions', () {
      expect(HomeRole.owner.canEditInventory, isTrue);
      expect(HomeRole.viewer.canEditInventory, isFalse);
      expect(HomeRole.admin.canManageMembers, isTrue);
      expect(HomeRole.editor.canManageMembers, isFalse);
      expect(HomeRole.fromDb('EDITOR'), HomeRole.editor);
    });

    test('Phase 6 enums parse database values', () {
      expect(InventoryTransactionType.fromDb('RESTOCK').label, 'Restock');
      expect(TripStatus.fromDb('ACTIVE'), TripStatus.active);
      expect(TripItemStatus.fromDb('UNPACKED'), TripItemStatus.unpacked);
    });
  });

  group('models', () {
    test('Profile.greetingName', () {
      expect(
        const Profile(id: '1', displayName: 'Aldoni Latumahina').greetingName,
        'Aldoni',
      );
      expect(
        const Profile(id: '1', email: 'user@example.com').greetingName,
        'user',
      );
    });

    test('Home.fromJson', () {
      final home = Home.fromJson({
        'id': 'h1',
        'name': 'Bangkok Apartment',
        'description': null,
        'remarks': 'Near the park',
        'cover_image_id': 'img1',
        'address_text': null,
        'residing_since': '2024-03-01',
        'timezone': 'Asia/Bangkok',
        'default_currency': 'THB',
        'created_by_user_id': 'u1',
        'archived_at': null,
      }, myRole: HomeRole.owner);
      expect(home.name, 'Bangkok Apartment');
      expect(home.coverImageId, 'img1');
      expect(home.remarks, 'Near the park');
      expect(home.residingSince?.year, 2024);
      expect(home.myRole, HomeRole.owner);
      expect(home.isArchived, isFalse);
      expect(home.toUpdateJson()['timezone'], 'Asia/Bangkok');
      expect(
        home.residenceDurationLabel(DateTime(2026, 7, 1)),
        'Living here for 2 years, 4 months',
      );
    });

    test('Room.fromJson', () {
      final room = Room.fromJson({
        'id': 'r1',
        'home_id': 'h1',
        'name': 'Kitchen',
        'description': null,
        'sort_order': 2,
        'created_by_user_id': 'u1',
        'archived_at': null,
      });
      expect(room.sortOrder, 2);
    });

    test('InventoryNode.fromJson item-as-container', () {
      final node = InventoryNode.fromJson({
        'id': 'n1',
        'home_id': 'h1',
        'room_id': 'r1',
        'parent_node_id': null,
        'node_kind': 'ITEM',
        'name': 'Black Suitcase',
        'description': null,
        'is_container': true,
        'is_mobile_container': true,
        'is_disposed': false,
        'disposed_at': null,
        'is_dispenser': true,
        'dispenser_mode': 'MULTI',
        'is_dispensable': false,
        'capacity': 10,
        'item_category': 'BAG_LUGGAGE',
        'quantity': 1,
        'quantity_unit': 'pcs',
        'weight': 3.5,
        'weight_unit': 'kg',
        'created_by_user_id': 'u1',
        'archived_at': null,
      });
      expect(node.isContainer, isTrue);
      expect(node.isMobileContainer, isTrue);
      expect(node.itemCategory, ItemCategory.bagLuggage);
      expect(node.kindLabel, 'Mobile container');
      expect(node.isDisposed, isFalse);
      expect(node.isDispenser, isTrue);
      expect(node.effectiveDispenserMode, DispenserMode.multi);
      expect(node.isDispensable, isFalse);
      expect(node.capacity, 10);
      expect(node.weight, 3.5);
      expect(node.weightUnit, 'kg');
    });
  });
}
