import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeventory/features/reminders/presentation/edit_reminder_screen.dart';
import 'package:homeventory/features/reminders/presentation/item_schedule_panel.dart';
import 'package:homeventory/shared/widgets/home_shell_bottom_nav.dart';

void main() {
  testWidgets('phone bottom nav includes a Schedule tab', (tester) async {
    var selected = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: HomeShellBottomNav(
            selectedIndex: HomeShellNav.home,
            onSelect: (index) async => selected = index,
          ),
        ),
      ),
    );

    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Trips'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);

    await tester.tap(find.text('Schedule'));
    await tester.pump();
    expect(selected, HomeShellNav.schedule);
  });

  testWidgets('item edit schedule panel can turn on an alarm', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ItemSchedulePanel(homeId: 'home-1', itemName: 'Soap'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('NOTIFICATION SCHEDULE'), findsOneWidget);
    expect(find.text('Notify me'), findsOneWidget);
    expect(find.text('Notification title'), findsNothing);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    expect(find.text('Notification title'), findsOneWidget);
    expect(find.text('Alarm (your text and repeat)'), findsOneWidget);
  });

  testWidgets('new schedule form can link an item or a room', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: EditReminderScreen(homeId: 'home-1')),
      ),
    );

    expect(find.text('LINKED TO'), findsOneWidget);
    expect(find.text('Item'), findsOneWidget);
    expect(find.text('Room'), findsOneWidget);
    expect(find.textContaining('room or an item'), findsOneWidget);
    expect(find.text('Search by name…'), findsOneWidget);
  });
}
