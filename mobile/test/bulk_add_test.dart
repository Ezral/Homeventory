import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeventory/shared/models/bulk_node_draft.dart';
import 'package:homeventory/shared/models/enums.dart';
import 'package:homeventory/shared/widgets/bulk_add_dialog.dart';

void main() {
  group('bulk drafts', () {
    test('namedBulkDrafts drops blanks and trims', () {
      expect(
        namedBulkDrafts(const [
          BulkNodeDraft(name: '  Desk  ', type: InventoryTypeChoice.furniture),
          BulkNodeDraft(name: '   '),
          BulkNodeDraft(name: 'Lamp', quantity: 2, purchasePrice: 12.5),
        ]),
        [
          const BulkNodeDraft(
            name: 'Desk',
            type: InventoryTypeChoice.furniture,
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

    test('applyTypeToDrafts with none checked updates every row', () {
      const drafts = [BulkNodeDraft(name: 'Desk'), BulkNodeDraft(name: 'Lamp')];
      final updated = applyTypeToDrafts(
        drafts: drafts,
        type: InventoryTypeChoice.storage,
        selectedIndices: {},
      );
      expect(
        updated.every((d) => d.type == InventoryTypeChoice.storage),
        isTrue,
      );
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

  group('BulkAddTable', () {
    testWidgets('saves named rows with qty, price, and per-row type', (
      tester,
    ) async {
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
      expect(saved![1].name, 'Lamp');
      expect(saved![1].type, InventoryTypeChoice.item);
      expect(saved![1].quantity, 2);
    });

    testWidgets('set type of selected leaves unchecked rows alone', (
      tester,
    ) async {
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

      await tester.tap(find.byKey(const ValueKey('bulk-type-apply')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Furniture').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('bulk-save')));
      await tester.pumpAndSettle();

      expect(saved![0].type, InventoryTypeChoice.furniture);
      expect(saved![1].type, InventoryTypeChoice.item);
    });

    testWidgets('set type for all updates every row when none are checked', (
      tester,
    ) async {
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

      await tester.tap(find.byKey(const ValueKey('bulk-type-apply')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Storage').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('bulk-save')));
      await tester.pumpAndSettle();

      expect(saved![0].type, InventoryTypeChoice.storage);
      expect(saved![1].type, InventoryTypeChoice.storage);
    });

    testWidgets('item rows can be changed to clothing', (tester) async {
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

      expect(find.text('Clothing'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('bulk-type-apply')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clothing').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('bulk-save')));
      await tester.pumpAndSettle();

      expect(saved![0].type, InventoryTypeChoice.clothing);
      expect(saved![1].type, InventoryTypeChoice.clothing);
    });
  });
}
