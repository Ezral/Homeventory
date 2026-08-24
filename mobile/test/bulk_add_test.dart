import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeventory/shared/models/bulk_node_draft.dart';
import 'package:homeventory/shared/models/enums.dart';
import 'package:homeventory/shared/models/inventory_node.dart';
import 'package:homeventory/shared/widgets/bulk_add_dialog.dart';
import 'package:homeventory/shared/widgets/bulk_edit_fields.dart';

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
  });
}
