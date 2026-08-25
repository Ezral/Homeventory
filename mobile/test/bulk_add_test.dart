import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeventory/shared/models/bulk_node_draft.dart';
import 'package:homeventory/shared/models/enums.dart';
import 'package:homeventory/shared/models/inventory_node.dart';
import 'package:homeventory/shared/utils/image_pick.dart';
import 'package:homeventory/shared/widgets/bulk_add_dialog.dart';
import 'package:homeventory/shared/widgets/bulk_edit_fields.dart';
import 'package:homeventory/shared/widgets/image_ingest_region.dart';

InventoryNode _item({
  required String id,
  required String name,
  InventoryNodeKind kind = InventoryNodeKind.item,
  ItemCategory? category,
  double? quantity,
  double? price,
  String? brand,
  double? weight,
}) {
  return InventoryNode(
    id: id,
    homeId: 'h1',
    roomId: 'r1',
    nodeKind: kind,
    name: name,
    itemCategory: category,
    quantity: quantity,
    purchasePrice: price,
    brand: brand,
    weight: weight,
    createdByUserId: 'u1',
  );
}

/// 1×1 PNG so [Image.memory] can decode in widget tests.
final _pngBytes = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

PickedImageBytes _pickedPhoto() {
  return PickedImageBytes(
    bytes: _pngBytes,
    mimeType: 'image/png',
    extension: 'png',
  );
}

void main() {
  group('bulk drafts', () {
    test('namedBulkDrafts drops blanks and trims brand', () {
      expect(
        namedBulkDrafts(const [
          BulkNodeDraft(
            name: '  Desk  ',
            type: InventoryTypeChoice.furniture,
            brand: '  Ikea  ',
            weight: 12,
          ),
          BulkNodeDraft(name: '   '),
          BulkNodeDraft(name: 'Lamp', quantity: 2, purchasePrice: 12.5),
        ]),
        [
          const BulkNodeDraft(
            name: 'Desk',
            type: InventoryTypeChoice.furniture,
            brand: 'Ikea',
            weight: 12,
            weightUnit: 'g',
          ),
          const BulkNodeDraft(name: 'Lamp', quantity: 2, purchasePrice: 12.5),
        ],
      );
    });

    test('namedBulkDrafts keeps photos on named rows', () {
      final photo = BulkPendingPhoto(
        bytes: Uint8List.fromList(const [1, 2, 3]),
        mimeType: 'image/jpeg',
      );
      final kept = namedBulkDrafts([
        BulkNodeDraft(name: 'Lamp', photos: [photo]),
        const BulkNodeDraft(name: '  '),
      ]);
      expect(kept, hasLength(1));
      expect(kept.first.photos, hasLength(1));
      expect(kept.first.photos.first.bytes, [1, 2, 3]);
    });

    test('namedBulkDrafts keeps placement on named rows', () {
      const placement = BulkPlacement(
        roomId: 'r2',
        parentNodeId: 'c1',
        label: 'Bedroom › Closet',
      );
      final kept = namedBulkDrafts(const [
        BulkNodeDraft(name: 'Lamp', placement: placement),
        BulkNodeDraft(name: '  ', placement: placement),
      ]);
      expect(kept, hasLength(1));
      expect(kept.first.placement, placement);
    });

    test('formatBulkPlacementLabel joins room and containers', () {
      expect(formatBulkPlacementLabel(roomName: 'Kitchen'), 'Kitchen');
      expect(
        formatBulkPlacementLabel(
          roomName: 'Kitchen',
          containerNames: const ['Closet', 'Drawer'],
        ),
        'Kitchen › Closet › Drawer',
      );
    });

    test('bulkCreateTarget prefers the draft placement', () {
      const draft = BulkNodeDraft(
        name: 'Lamp',
        placement: BulkPlacement(roomId: 'r2', parentNodeId: 'c1'),
      );
      final target = bulkCreateTarget(
        draft: draft,
        fallbackRoomId: 'r1',
        fallbackParentNodeId: 'p0',
      );
      expect(target.roomId, 'r2');
      expect(target.parentNodeId, 'c1');
      final fallback = bulkCreateTarget(
        draft: const BulkNodeDraft(name: 'Lamp'),
        fallbackRoomId: 'r1',
        fallbackParentNodeId: 'p0',
      );
      expect(fallback.roomId, 'r1');
      expect(fallback.parentNodeId, 'p0');
    });

    test('parseOptionalNumber treats blank and junk as omitted', () {
      expect(parseOptionalNumber(''), isNull);
      expect(parseOptionalNumber('  '), isNull);
      expect(parseOptionalNumber('abc'), isNull);
      expect(parseOptionalNumber('2'), 2);
      expect(parseOptionalNumber('1,250.5'), 1250.5);
    });

    test('applyTypeToDrafts updates only checked rows', () {
      const drafts = [
        BulkNodeDraft(name: 'Desk'),
        BulkNodeDraft(name: 'Lamp'),
        BulkNodeDraft(name: 'Bin'),
      ];
      final updated = applyTypeToDrafts(
        drafts: drafts,
        type: InventoryTypeChoice.furniture,
        selectedIndices: {0, 2},
      );
      expect(updated[0].type, InventoryTypeChoice.furniture);
      expect(updated[1].type, InventoryTypeChoice.item);
      expect(updated[2].type, InventoryTypeChoice.furniture);
    });

    test('applyPatchToDrafts writes quantity and brand onto selected rows', () {
      const drafts = [
        BulkNodeDraft(name: 'Desk', quantity: 1),
        BulkNodeDraft(name: 'Lamp', quantity: 1, brand: 'Old'),
      ];
      final updated = applyPatchToDrafts(
        drafts: drafts,
        patch: const BulkNodePatch(
          applyQuantity: true,
          quantity: 4,
          applyBrand: true,
          brand: 'Nike',
        ),
        selectedIndices: {1},
      );
      expect(updated[0].quantity, 1);
      expect(updated[0].brand, isNull);
      expect(updated[1].quantity, 4);
      expect(updated[1].brand, 'Nike');
    });

    test('applyPatchToDrafts writes location onto selected rows', () {
      const drafts = [
        BulkNodeDraft(
          name: 'Desk',
          placement: BulkPlacement(roomId: 'r1', label: 'Kitchen'),
        ),
        BulkNodeDraft(
          name: 'Lamp',
          placement: BulkPlacement(roomId: 'r1', label: 'Kitchen'),
        ),
      ];
      const closet = BulkPlacement(
        roomId: 'r2',
        parentNodeId: 'c1',
        label: 'Bedroom › Closet',
      );
      final updated = applyPatchToDrafts(
        drafts: drafts,
        patch: const BulkNodePatch(applyPlacement: true, placement: closet),
        selectedIndices: {1},
      );
      expect(updated[0].placement?.roomId, 'r1');
      expect(updated[1].placement, closet);
    });

    test('sharedValuesFromDrafts marks mixed quantity', () {
      const drafts = [
        BulkNodeDraft(name: 'A', quantity: 2, brand: 'Nike'),
        BulkNodeDraft(name: 'B', quantity: 3, brand: 'Nike'),
      ];
      final shared = sharedValuesFromDrafts(drafts);
      expect(shared.quantityMixed, isTrue);
      expect(shared.quantity, isNull);
      expect(shared.brandMixed, isFalse);
      expect(shared.brand, 'Nike');
    });

    test('sharedValuesFromNodes fills matching type and quantity', () {
      final shared = sharedValuesFromNodes([
        _item(id: '1', name: 'Tee', quantity: 2, brand: 'Uniqlo'),
        _item(id: '2', name: 'Shirt', quantity: 2, brand: 'Uniqlo'),
      ]);
      expect(shared.type, InventoryTypeChoice.item);
      expect(shared.quantity, 2);
      expect(shared.brand, 'Uniqlo');
      expect(shared.typeMixed, isFalse);
    });

    test('BulkNodeDraft.fromNode copies per-item fields', () {
      final draft = BulkNodeDraft.fromNode(
        _item(
          id: '1',
          name: 'Tee',
          quantity: 2,
          price: 15,
          brand: 'Uniqlo',
          weight: 180,
        ),
      );
      expect(draft.name, 'Tee');
      expect(draft.quantity, 2);
      expect(draft.purchasePrice, 15);
      expect(draft.brand, 'Uniqlo');
      expect(draft.weight, 180);
      expect(draft.type, InventoryTypeChoice.item);
    });

    test('clothing type maps to item + clothing category', () {
      const draft = BulkNodeDraft(
        name: 'Jeans',
        type: InventoryTypeChoice.clothing,
      );
      expect(draft.type.nodeKind, InventoryNodeKind.item);
      expect(draft.type.itemCategory, ItemCategory.clothing);
      expect(draft.isItemLike, isTrue);
    });
  });

  group('BulkEditFields', () {
    testWidgets('shows shared quantity and Mixed for type', (tester) async {
      BulkNodePatch? patch;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BulkEditFields(
              initial: const SharedBulkValues(
                typeMixed: true,
                quantity: 2,
                brand: 'Nike',
              ),
              applyLabel: 'Apply',
              onApply: (p) => patch = p,
            ),
          ),
        ),
      );

      expect(find.text('Mixed'), findsWidgets);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('bulk-edit-qty')))
            .controller
            ?.text,
        '2',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('bulk-edit-brand')))
            .controller
            ?.text,
        'Nike',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('bulk-edit-qty')))
            .style
            ?.fontSize,
        11,
      );

      await tester.enterText(find.byKey(const ValueKey('bulk-edit-qty')), '6');
      await tester.tap(find.byKey(const ValueKey('bulk-edit-apply')));
      await tester.pump();

      expect(patch, isNotNull);
      expect(patch!.type, isNull);
      expect(patch!.applyQuantity, isTrue);
      expect(patch!.quantity, 6);
      expect(patch!.applyBrand, isTrue);
      expect(patch!.brand, 'Nike');
    });

    testWidgets('location field applies the picked placement', (tester) async {
      BulkNodePatch? patch;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BulkEditFields(
              initial: const SharedBulkValues(
                placement: BulkPlacement(roomId: 'r1', label: 'Kitchen'),
              ),
              applyLabel: 'Apply',
              pickLocation: (current) async => const BulkPlacement(
                roomId: 'r2',
                parentNodeId: 'c1',
                label: 'Bedroom › Closet',
              ),
              onApply: (p) => patch = p,
            ),
          ),
        ),
      );

      expect(find.text('Kitchen'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('bulk-edit-location')));
      await tester.pumpAndSettle();
      expect(find.text('Bedroom › Closet'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('bulk-edit-apply')));
      await tester.pump();

      expect(patch, isNotNull);
      expect(patch!.applyPlacement, isTrue);
      expect(patch!.placement?.roomId, 'r2');
      expect(patch!.placement?.parentNodeId, 'c1');
    });
  });

  group('BulkAddTable', () {
    Future<void> useWideSurface(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }

    testWidgets('saves named rows with qty, price, brand, and weight', (
      tester,
    ) async {
      await useWideSurface(tester);
      List<BulkNodeDraft>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BulkAddTable(
              initialRowCount: 3,
              onClose: () {},
              onSave: (drafts) async => saved = drafts,
            ),
          ),
        ),
      );

      await tester.enterText(find.byKey(const ValueKey('bulk-name-0')), 'Desk');
      await tester.enterText(find.byKey(const ValueKey('bulk-qty-0')), '1');
      await tester.enterText(find.byKey(const ValueKey('bulk-price-0')), '40');
      await tester.enterText(
        find.byKey(const ValueKey('bulk-brand-0')),
        'Ikea',
      );
      await tester.enterText(find.byKey(const ValueKey('bulk-weight-0')), '12');
      await tester.tap(find.byKey(const ValueKey('bulk-type-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Furniture').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('bulk-name-1')), 'Lamp');
      await tester.enterText(find.byKey(const ValueKey('bulk-qty-1')), '2');

      await tester.tap(find.byKey(const ValueKey('bulk-save')));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved, hasLength(2));
      expect(saved![0].name, 'Desk');
      expect(saved![0].type, InventoryTypeChoice.furniture);
      expect(saved![0].quantity, 1);
      expect(saved![0].purchasePrice, 40);
      expect(saved![0].brand, 'Ikea');
      expect(saved![0].weight, 12);
      expect(saved![1].name, 'Lamp');
      expect(saved![1].quantity, 2);
    });

    testWidgets('apply to selected leaves unchecked rows alone', (
      tester,
    ) async {
      await useWideSurface(tester);
      List<BulkNodeDraft>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BulkAddTable(
              initialRowCount: 3,
              onClose: () {},
              onSave: (drafts) async => saved = drafts,
            ),
          ),
        ),
      );

      await tester.enterText(find.byKey(const ValueKey('bulk-name-0')), 'Desk');
      await tester.enterText(find.byKey(const ValueKey('bulk-name-1')), 'Lamp');
      await tester.tap(find.byKey(const ValueKey('bulk-select-0')));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('bulk-edit-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Furniture').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bulk-edit-apply')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('bulk-save')));
      await tester.pumpAndSettle();

      expect(saved![0].type, InventoryTypeChoice.furniture);
      expect(saved![1].type, InventoryTypeChoice.item);
    });

    testWidgets('apply to all updates every row when none are checked', (
      tester,
    ) async {
      await useWideSurface(tester);
      List<BulkNodeDraft>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BulkAddTable(
              initialRowCount: 3,
              onClose: () {},
              onSave: (drafts) async => saved = drafts,
            ),
          ),
        ),
      );

      await tester.enterText(find.byKey(const ValueKey('bulk-name-0')), 'Bin');
      await tester.enterText(find.byKey(const ValueKey('bulk-name-1')), 'Box');

      await tester.tap(find.byKey(const ValueKey('bulk-edit-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Storage').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bulk-edit-apply')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('bulk-save')));
      await tester.pumpAndSettle();

      expect(saved![0].type, InventoryTypeChoice.storage);
      expect(saved![1].type, InventoryTypeChoice.storage);
    });

    testWidgets('item rows can be changed to clothing', (tester) async {
      await useWideSurface(tester);
      List<BulkNodeDraft>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BulkAddTable(
              initialRowCount: 3,
              onClose: () {},
              onSave: (drafts) async => saved = drafts,
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('bulk-name-0')),
        'Jeans',
      );
      await tester.enterText(
        find.byKey(const ValueKey('bulk-name-1')),
        'Sweater',
      );
      await tester.tap(find.byKey(const ValueKey('bulk-select-0')));
      await tester.tap(find.byKey(const ValueKey('bulk-select-1')));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('bulk-edit-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clothing').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bulk-edit-apply')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('bulk-save')));
      await tester.pumpAndSettle();

      expect(saved![0].type, InventoryTypeChoice.clothing);
      expect(saved![1].type, InventoryTypeChoice.clothing);
    });

    testWidgets('edit mode shows one prefilled row per selected item', (
      tester,
    ) async {
      await useWideSurface(tester);
      List<BulkNodeDraft>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BulkAddTable(
              existingNodes: [
                _item(
                  id: '1',
                  name: 'Tee',
                  quantity: 2,
                  brand: 'Uniqlo',
                  weight: 180,
                ),
                _item(
                  id: '2',
                  name: 'Jeans',
                  category: ItemCategory.clothing,
                  quantity: 1,
                  price: 40,
                ),
              ],
              onClose: () {},
              onSave: (drafts) async => saved = drafts,
            ),
          ),
        ),
      );

      expect(find.text('Edit selected'), findsOneWidget);
      expect(find.byKey(const ValueKey('bulk-add-row')), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('bulk-name-0')))
            .controller
            ?.text,
        'Tee',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('bulk-name-0')))
            .style
            ?.fontSize,
        11,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('bulk-name-1')))
            .controller
            ?.text,
        'Jeans',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('bulk-qty-0')))
            .controller
            ?.text,
        '2',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('bulk-brand-0')))
            .controller
            ?.text,
        'Uniqlo',
      );

      await tester.enterText(find.byKey(const ValueKey('bulk-qty-0')), '5');
      await tester.enterText(
        find.byKey(const ValueKey('bulk-brand-1')),
        'Levi\'s',
      );
      await tester.tap(find.byKey(const ValueKey('bulk-save')));
      await tester.pumpAndSettle();

      expect(saved, hasLength(2));
      expect(saved![0].name, 'Tee');
      expect(saved![0].quantity, 5);
      expect(saved![0].brand, 'Uniqlo');
      expect(saved![1].name, 'Jeans');
      expect(saved![1].type, InventoryTypeChoice.clothing);
      expect(saved![1].brand, "Levi's");
      expect(saved![1].quantity, 1);
    });

    testWidgets('edit mode attaches multiple photos per row before save', (
      tester,
    ) async {
      await useWideSurface(tester);
      List<BulkNodeDraft>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BulkAddTable(
              existingNodes: [
                _item(id: '1', name: 'Tee'),
                _item(id: '2', name: 'Jeans'),
              ],
              pickImage: (_) async => _pickedPhoto(),
              onClose: () {},
              onSave: (drafts) async => saved = drafts,
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('bulk-photo-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('bulk-photo-1')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('bulk-photo-0')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bulk-photo-0')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bulk-photo-1')));
      await tester.pump();

      expect(find.byKey(const ValueKey('bulk-photo-remove-0')), findsOneWidget);
      expect(find.text('2'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('bulk-save')));
      await tester.pumpAndSettle();

      expect(saved, hasLength(2));
      expect(saved![0].photos, hasLength(2));
      expect(saved![1].photos, hasLength(1));
      expect(saved![0].photos.first.mimeType, 'image/png');
    });

    testWidgets('photo remove drops the last pending picture', (tester) async {
      await useWideSurface(tester);
      List<BulkNodeDraft>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BulkAddTable(
              existingNodes: [_item(id: '1', name: 'Tee')],
              pickImage: (_) async => _pickedPhoto(),
              onClose: () {},
              onSave: (drafts) async => saved = drafts,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('bulk-photo-0')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bulk-photo-remove-0')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bulk-save')));
      await tester.pumpAndSettle();

      expect(saved, hasLength(1));
      expect(saved![0].photos, isEmpty);
    });

    testWidgets('dropped images attach to the hovered row', (tester) async {
      await useWideSurface(tester);
      List<BulkNodeDraft>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BulkAddTable(
              existingNodes: [
                _item(id: '1', name: 'Tee'),
                _item(id: '2', name: 'Jeans'),
              ],
              onClose: () {},
              onSave: (drafts) async => saved = drafts,
            ),
          ),
        ),
      );

      expect(find.byType(ImageIngestRegion), findsNWidgets(3));
      tester
          .widget<ImageIngestRegion>(
            find.byKey(const ValueKey('bulk-row-ingest-0')),
          )
          .onImages([_pickedPhoto(), _pickedPhoto()]);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bulk-save')));
      await tester.pumpAndSettle();

      expect(saved, hasLength(2));
      expect(saved![0].photos, hasLength(2));
      expect(saved![1].photos, isEmpty);
    });

    testWidgets('pasted images attach to checked rows', (tester) async {
      await useWideSurface(tester);
      List<BulkNodeDraft>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BulkAddTable(
              existingNodes: [
                _item(id: '1', name: 'Tee'),
                _item(id: '2', name: 'Jeans'),
              ],
              onClose: () {},
              onSave: (drafts) async => saved = drafts,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('bulk-select-0')));
      await tester.pump();
      tester
          .widget<ImageIngestRegion>(find.byKey(const ValueKey('bulk-paste')))
          .onImages([_pickedPhoto()]);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bulk-save')));
      await tester.pumpAndSettle();

      expect(saved, hasLength(2));
      expect(saved![0].photos, hasLength(1));
      expect(saved![1].photos, isEmpty);
    });

    testWidgets('paste without a checked row shows a hint', (tester) async {
      await useWideSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BulkAddTable(
              existingNodes: [
                _item(id: '1', name: 'Tee'),
                _item(id: '2', name: 'Jeans'),
              ],
              onClose: () {},
              onSave: (_) async {},
            ),
          ),
        ),
      );

      tester
          .widget<ImageIngestRegion>(find.byKey(const ValueKey('bulk-paste')))
          .onImages([_pickedPhoto()]);
      await tester.pump();
      expect(find.text('Check a row, then paste the photo.'), findsOneWidget);
    });

    testWidgets('applying location sets placement on selected add rows', (
      tester,
    ) async {
      await useWideSurface(tester);
      List<BulkNodeDraft>? saved;
      const kitchen = BulkPlacement(roomId: 'r1', label: 'Kitchen');
      const closet = BulkPlacement(
        roomId: 'r2',
        parentNodeId: 'c1',
        label: 'Bedroom › Closet',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BulkAddTable(
              initialRowCount: 2,
              defaultPlacement: kitchen,
              pickLocation: (context, current) async => closet,
              onClose: () {},
              onSave: (drafts) async => saved = drafts,
            ),
          ),
        ),
      );

      expect(find.text('Kitchen'), findsWidgets);
      await tester.enterText(find.byKey(const ValueKey('bulk-name-0')), 'Lamp');
      await tester.enterText(find.byKey(const ValueKey('bulk-name-1')), 'Mug');
      await tester.tap(find.byKey(const ValueKey('bulk-select-0')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bulk-edit-location')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bulk-edit-apply')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bulk-save')));
      await tester.pumpAndSettle();

      expect(saved, hasLength(2));
      expect(saved![0].placement, closet);
      expect(saved![1].placement, kitchen);
    });
  });
}
