import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../core/theme/app_theme.dart';

/// Pixel layout for the Android schedule notification card.
///
/// 2:1 matches Android's BigPicture recommendation so the shade does not
/// crop the left-image / right-text split.
abstract final class ScheduleNotificationCardLayout {
  static const width = 1080.0;
  static const height = 540.0;

  /// Left third is the item/room photo.
  static double get imageWidth => width / 3;
  static double get textWidth => width - imageWidth;
}

/// Builds a PNG card: photo on the left third, title and body on the right.
Future<Uint8List> composeScheduleNotificationCard({
  Uint8List? photoBytes,
  required String title,
  required String body,
}) async {
  const width = ScheduleNotificationCardLayout.width;
  const height = ScheduleNotificationCardLayout.height;
  final imageWidth = ScheduleNotificationCardLayout.imageWidth;
  final textWidth = ScheduleNotificationCardLayout.textWidth;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, width, height));

  canvas.drawRect(
    ui.Rect.fromLTWH(imageWidth, 0, textWidth, height),
    ui.Paint()..color = AppColors.paperElevated,
  );

  final imageRect = ui.Rect.fromLTWH(0, 0, imageWidth, height);
  final photo = photoBytes == null ? null : await _decodeImage(photoBytes);
  if (photo != null) {
    _paintCover(canvas, photo, imageRect);
    photo.dispose();
  } else {
    canvas.drawRect(imageRect, ui.Paint()..color = AppColors.mossSoft);
  }

  const pad = 28.0;
  final textMax = textWidth - pad * 2;
  final titlePara = _paragraph(
    title.trim().isEmpty ? 'Schedule' : title.trim(),
    fontSize: 42,
    color: AppColors.ink,
    weight: ui.FontWeight.w600,
    maxWidth: textMax,
    maxLines: 2,
  );
  final bodyPara = _paragraph(
    body.trim(),
    fontSize: 28,
    color: AppColors.inkMuted,
    weight: ui.FontWeight.w400,
    maxWidth: textMax,
    maxLines: 3,
  );
  final textBlockHeight =
      titlePara.height + (body.trim().isEmpty ? 0 : 12 + bodyPara.height);
  var y = (height - textBlockHeight) / 2;
  if (y < pad) y = pad;
  canvas.drawParagraph(titlePara, ui.Offset(imageWidth + pad, y));
  y += titlePara.height + 12;
  if (body.trim().isNotEmpty) {
    canvas.drawParagraph(bodyPara, ui.Offset(imageWidth + pad, y));
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(width.toInt(), height.toInt());
  picture.dispose();
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

Future<ui.Image?> _decodeImage(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (_) {
    return null;
  }
}

void _paintCover(ui.Canvas canvas, ui.Image image, ui.Rect dst) {
  final srcW = image.width.toDouble();
  final srcH = image.height.toDouble();
  if (srcW <= 0 || srcH <= 0) return;
  final scale = math.max(dst.width / srcW, dst.height / srcH);
  final w = srcW * scale;
  final h = srcH * scale;
  final dx = dst.left + (dst.width - w) / 2;
  final dy = dst.top + (dst.height - h) / 2;
  canvas.save();
  canvas.clipRect(dst);
  canvas.drawImageRect(
    image,
    ui.Rect.fromLTWH(0, 0, srcW, srcH),
    ui.Rect.fromLTWH(dx, dy, w, h),
    ui.Paint()..filterQuality = ui.FilterQuality.medium,
  );
  canvas.restore();
}

ui.Paragraph _paragraph(
  String text, {
  required double fontSize,
  required ui.Color color,
  required ui.FontWeight weight,
  required double maxWidth,
  required int maxLines,
}) {
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            fontSize: fontSize,
            fontWeight: weight,
            maxLines: maxLines,
            ellipsis: '…',
          ),
        )
        ..pushStyle(
          ui.TextStyle(color: color, fontSize: fontSize, fontWeight: weight),
        )
        ..addText(text.isEmpty ? ' ' : text);
  final paragraph = builder.build();
  paragraph.layout(ui.ParagraphConstraints(width: maxWidth));
  return paragraph;
}
