import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeventory/shared/utils/image_pick.dart';
import 'package:homeventory/shared/widgets/image_ingest_region.dart';

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

void main() {
  group('pickedImageFromRaw', () {
    test('sniffs png bytes', () {
      final picked = pickedImageFromRaw(bytes: _pngBytes);
      expect(picked, isNotNull);
      expect(picked!.mimeType, 'image/png');
      expect(picked.extension, 'png');
    });

    test('uses filename when bytes are not sniffed as image', () {
      final picked = pickedImageFromRaw(
        bytes: Uint8List.fromList(List.filled(16, 0)),
        filename: 'shot.jpg',
      );
      expect(picked, isNotNull);
      expect(picked!.mimeType, 'image/jpeg');
      expect(picked.extension, 'jpg');
    });

    test('rejects empty and svg', () {
      expect(pickedImageFromRaw(bytes: Uint8List(0)), isNull);
      expect(
        pickedImageFromRaw(
          bytes: Uint8List.fromList(const [
            1,
            2,
            3,
            4,
            5,
            6,
            7,
            8,
            9,
            10,
            11,
            12,
          ]),
          mimeType: 'image/svg+xml',
        ),
        isNull,
      );
    });
  });

  testWidgets('ImageIngestRegion builds its child', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageIngestRegion(
            onImages: (_) {},
            child: const Text('photo drop'),
          ),
        ),
      ),
    );
    expect(find.text('photo drop'), findsOneWidget);
  });
}
