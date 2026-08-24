import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeventory/shared/widgets/entity_photo_gallery.dart';

void main() {
  testWidgets('editors can delete a photo from the overlay', (tester) async {
    String? deletedId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EntityPhotoGallery(
            images: const [GalleryPhoto(id: 'img-1')],
            canEdit: true,
            onDelete: (id) async => deletedId = id,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Delete photo'));
    await tester.pumpAndSettle();

    expect(find.text('Delete photo?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(deletedId, 'img-1');
  });

  testWidgets('viewers do not see a delete control', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EntityPhotoGallery(
            images: [GalleryPhoto(id: 'img-1')],
          ),
        ),
      ),
    );

    expect(find.byTooltip('Delete photo'), findsNothing);
    expect(find.text('Delete photo'), findsNothing);
  });
}
