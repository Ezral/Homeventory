import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeventory/core/layout/web_layout.dart';
import 'package:homeventory/features/search/presentation/search_screen.dart';
import 'package:homeventory/shared/models/enums.dart';
import 'package:homeventory/shared/utils/inventory_labels.dart';
import 'package:homeventory/shared/widgets/inventory_row_card.dart';

void main() {
  test('a single match stays one column wide', () {
    expect(searchResultColumnCount(availableWidth: 1400, resultCount: 1), 1);
  });

  test('multiple matches use four columns on a wide row', () {
    expect(searchResultColumnCount(availableWidth: 1200, resultCount: 9), 4);
  });

  test('two matches stay two columns even on a wide row', () {
    expect(searchResultColumnCount(availableWidth: 1200, resultCount: 2), 2);
  });

  test('a narrow phone stays one column', () {
    expect(searchResultColumnCount(availableWidth: 360, resultCount: 8), 1);
  });

  test('medium width grows to two or three columns', () {
    expect(searchResultColumnCount(availableWidth: 500, resultCount: 8), 2);
    expect(searchResultColumnCount(availableWidth: 750, resultCount: 8), 3);
  });

  test('bulk names split on lines, commas, and semicolons', () {
    expect(
      parseBulkItemNames('USB-C charger\nPassport, Sunscreen; Umbrella\n'),
      ['USB-C charger', 'Passport', 'Sunscreen', 'Umbrella'],
    );
    expect(parseBulkItemNames('  \n  '), isEmpty);
  });

  testWidgets('editors see a checkbox on selectable cards', (tester) async {
    var checked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InventoryRowCard(
            title: 'Passport',
            fallbackIcon: Icons.inventory_2_outlined,
            showCheckbox: true,
            checked: checked,
            onToggleChecked: () => checked = true,
          ),
        ),
      ),
    );

    expect(find.byType(Checkbox), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    expect(checked, isTrue);
  });

  testWidgets('search type chips select clothing and can clear', (
    tester,
  ) async {
    InventoryTypeChoice? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SearchTypeFilterBar(
                selected: selected,
                onChanged: (type) => setState(() => selected = type),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Furniture'), findsOneWidget);
    expect(find.text('Storage'), findsOneWidget);
    expect(find.text('Item'), findsOneWidget);
    expect(find.text('Clothing'), findsOneWidget);

    await tester.tap(find.text('Clothing'));
    await tester.pump();
    expect(selected, InventoryTypeChoice.clothing);

    final clothingChip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Clothing'),
    );
    expect(clothingChip.selected, isTrue);

    await tester.tap(find.text('Clothing'));
    await tester.pump();
    expect(selected, isNull);
  });
}
