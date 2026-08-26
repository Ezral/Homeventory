import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:homeventory/features/reminders/data/notification_scheduler.dart';
import 'package:homeventory/shared/models/enums.dart';
import 'package:homeventory/shared/models/reminder.dart';
import 'package:homeventory/shared/utils/notification_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('left third is reserved for the photo', () {
    expect(ScheduleNotificationCardLayout.imageWidth, 360);
    expect(
      ScheduleNotificationCardLayout.imageWidth,
      ScheduleNotificationCardLayout.width / 3,
    );
    expect(
      ScheduleNotificationCardLayout.width /
          ScheduleNotificationCardLayout.height,
      2,
    );
  });

  test('card is 1080x540 with the photo covering the left third', () async {
    final photo = await _solidPng(const ui.Color(0xFFCC3333), 80, 80);
    final png = await composeScheduleNotificationCard(
      photoBytes: photo,
      title: 'Buy more batteries',
      body: 'Kitchen · AAA batteries',
    );
    final image = await _decode(png);
    expect(image.width, ScheduleNotificationCardLayout.width.toInt());
    expect(image.height, ScheduleNotificationCardLayout.height.toInt());

    final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    expect(pixels, isNotNull);
    final data = pixels!.buffer.asUint8List();
    final width = ScheduleNotificationCardLayout.width.toInt();
    final height = ScheduleNotificationCardLayout.height.toInt();
    final imageWidth = ScheduleNotificationCardLayout.imageWidth.toInt();

    _expectRgbaNear(
      data,
      width,
      x: imageWidth ~/ 2,
      y: height ~/ 2,
      r: 0xCC,
      g: 0x33,
      b: 0x33,
    );
    _expectRgbaNear(
      data,
      width,
      x: imageWidth + 24,
      y: 24,
      r: 0xFF,
      g: 0xFF,
      b: 0xFF,
    );
  });

  test('missing photo uses the moss placeholder on the left third', () async {
    final png = await composeScheduleNotificationCard(
      title: 'Weekly clean-up',
      body: 'Kitchen',
    );
    final image = await _decode(png);
    final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    final data = pixels!.buffer.asUint8List();
    final width = ScheduleNotificationCardLayout.width.toInt();
    _expectRgbaNear(
      data,
      width,
      x: 40,
      y: ScheduleNotificationCardLayout.height.toInt() ~/ 2,
      r: 0xD7,
      g: 0xE8,
      b: 0xE0,
    );
  });

  test('fromReminder keeps a resolved photo URL', () {
    final reminder = Reminder(
      id: 'r1',
      homeId: 'h1',
      createdByUserId: 'u1',
      kind: ReminderKind.manual,
      title: 'Wipe counters',
      body: 'Kitchen',
      repeat: ReminderRepeat.weekly,
      fireMinute: 540,
      nextFireAt: DateTime(2026, 9, 2, 9),
      inventoryNodeId: 'n1',
      nodeName: 'Cloth',
    );
    final alert = ScheduledReminderAlert.fromReminder(
      reminder,
      imageUrl: 'https://example.test/cloth.png',
    );
    expect(alert.imageUrl, 'https://example.test/cloth.png');
    expect(alert.title, 'Wipe counters');
    expect(alert.body, 'Kitchen');
  });
}

Future<Uint8List> _solidPng(ui.Color color, int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = color,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}

Future<ui.Image> _decode(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  return frame.image;
}

void _expectRgbaNear(
  Uint8List data,
  int width, {
  required int x,
  required int y,
  required int r,
  required int g,
  required int b,
}) {
  final i = (y * width + x) * 4;
  expect(data[i], closeTo(r, 12), reason: 'R at ($x,$y)');
  expect(data[i + 1], closeTo(g, 12), reason: 'G at ($x,$y)');
  expect(data[i + 2], closeTo(b, 12), reason: 'B at ($x,$y)');
}
