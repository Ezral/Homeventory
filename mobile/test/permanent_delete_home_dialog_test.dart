import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeventory/features/homes/presentation/permanent_delete_home_dialog.dart';

void main() {
  Future<void> pumpDialog(WidgetTester tester, {required String homeName}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PermanentDeleteHomeDialog(homeName: homeName)),
      ),
    );
  }

  testWidgets('Delete forever stays disabled until the home name is typed', (
    tester,
  ) async {
    await pumpDialog(tester, homeName: 'Riverside loft');

    expect(find.text('Permanently delete Riverside loft?'), findsOneWidget);
    expect(find.textContaining('cannot be undone'), findsOneWidget);

    final delete = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Delete forever'),
    );
    expect(delete.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'riverside loft');
    await tester.pump();

    final enabled = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Delete forever'),
    );
    expect(enabled.onPressed, isNotNull);
  });

  testWidgets('Cancel pops false', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showPermanentDeleteHomeDialog(
                  context: context,
                  homeName: 'Studio',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
