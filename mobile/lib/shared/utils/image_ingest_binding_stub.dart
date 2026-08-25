import 'dart:ui';

import 'image_pick.dart';

/// No-op outside web. Paste / drop is a browser API.
class ImageIngestHandle {
  void cancel() {}
}

typedef ImageIngestHitTest = bool Function(Offset global);
typedef ImageIngestAccept = void Function(List<PickedImageBytes> images);
typedef ImageIngestDrag = void Function(bool over);

ImageIngestHandle registerImageIngestTarget({
  required ImageIngestHitTest containsPoint,
  required bool Function() canPaste,
  required ImageIngestAccept onImages,
  required ImageIngestDrag onDragOver,
}) {
  return ImageIngestHandle();
}
