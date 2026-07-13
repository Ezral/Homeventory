import 'package:flutter_test/flutter_test.dart';

import 'package:homeventory/core/config/app_config.dart';
import 'package:homeventory/core/utils/invite_token.dart';
import 'package:homeventory/shared/models/enums.dart';
import 'package:homeventory/shared/models/home.dart';
import 'package:homeventory/shared/models/inventory_node.dart';
import 'package:homeventory/shared/models/profile.dart';
import 'package:homeventory/shared/models/room.dart';
import 'package:homeventory/features/trips/data/trips_repository.dart';

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

    test('DispenserProductAssignment.fillLabel shows chamber fill', () {
      final assignment = DispenserProductAssignment.fromJson({
        'id': 'a1',
        'home_id': 'h1',
        'dispenser_item_id': 'd1',
        'product_item_id': 'p1',
        'slot_number': 2,
        'capacity': 300,
        'quantity': 120,
        'quantity_unit': 'CC',
        'product_name': 'Aloe gel',
      });
      expect(assignment.fillLabel, '120 / 300 CC');
      expect(assignment.slotNumber, 2);
    });
  });

  group('Trip weight', () {
    InventoryNode node({
      required String id,
      required String name,
      double? weight,
      String? unit,
    }) {
      return InventoryNode(
        id: id,
        homeId: 'h1',
        roomId: 'r1',
        nodeKind: InventoryNodeKind.item,
        name: name,
        isMobileContainer: true,
        isContainer: true,
        weight: weight,
        weightUnit: unit,
        createdByUserId: 'u1',
      );
    }

    test('inventoryWeightKg normalizes units', () {
      expect(inventoryWeightKg(node(id: '1', name: 'a', weight: 2, unit: 'kg')), 2);
      expect(inventoryWeightKg(node(id: '2', name: 'b', weight: 500, unit: 'g')), 0.5);
      expect(
        inventoryWeightKg(node(id: '3', name: 'c', weight: 10, unit: 'lb'))!,
        closeTo(4.5359, 0.001),
      );
    });

    test('buildTripWeightSummary sums containers + packed items', () {
      final trip = Trip.fromJson({
        'id': 't1',
        'home_id': 'h1',
        'name': 'Bali',
        'notes': null,
        'status': 'ACTIVE',
        'starts_on': null,
        'ends_on': null,
        'luggage_allowance_kg': 23,
        'archived_at': null,
        'created_by_user_id': 'u1',
        'created_at': '2026-07-13T00:00:00Z',
        'updated_at': '2026-07-13T00:00:00Z',
      });
      final suitcase = node(id: 's1', name: 'Suitcase', weight: 3, unit: 'kg');
      final shirt = node(id: 'i1', name: 'Shirt', weight: 400, unit: 'g');
      final summary = buildTripWeightSummary(
        trip: trip,
        containers: [
          TripContainer(
            id: 'tc1',
            homeId: 'h1',
            tripId: 't1',
            inventoryNodeId: suitcase.id,
            createdAt: DateTime.parse('2026-07-13T00:00:00Z'),
            node: suitcase,
          ),
        ],
        items: [
          TripItem(
            id: 'ti1',
            homeId: 'h1',
            tripId: 't1',
            inventoryNodeId: shirt.id,
            packedIntoNodeId: suitcase.id,
            originalRoomId: 'r1',
            status: TripItemStatus.packed,
            packedAt: DateTime.parse('2026-07-13T00:00:00Z'),
            packedByUserId: 'u1',
            node: shirt,
          ),
        ],
      );
      expect(summary.packedKg, closeTo(3.4, 0.0001));
      expect(summary.availableKg, closeTo(19.6, 0.0001));
      expect(summary.isOverAllowance, isFalse);
    });
  });
}
