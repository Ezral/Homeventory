import 'package:flutter_test/flutter_test.dart';
import 'package:homeventory/features/reminders/data/reminder_deep_link.dart';

void main() {
  test('item detail deep link includes homes list, home, and room', () {
    expect(reminderNavigationStack('/homes/h1/rooms/r1/nodes/n1/details'), [
      '/',
      '/homes/h1',
      '/homes/h1/rooms/r1',
      '/homes/h1/rooms/r1/nodes/n1/details',
    ]);
  });

  test('room deep link stacks home under the room', () {
    expect(reminderNavigationStack('/homes/h1/rooms/r1'), [
      '/',
      '/homes/h1',
      '/homes/h1/rooms/r1',
    ]);
  });

  test('schedule deep link stacks the home', () {
    expect(reminderNavigationStack('/homes/h1/schedule'), [
      '/',
      '/homes/h1',
      '/homes/h1/schedule',
    ]);
  });
}
