import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/layout/web_layout.dart';

class PickedImageBytes {
  const PickedImageBytes({
    required this.bytes,
    required this.mimeType,
    required this.extension,
  });

  final Uint8List bytes;
  final String mimeType;
  final String extension;
}

Future<PickedImageBytes?> pickEntityImage(BuildContext context) async {
  // Native + mobile web: offer camera. Desktop web: gallery/file is primary,
  // but webcam is still available if the browser supports it.
  final desktopWeb = kIsWeb && isWebDesktopLayout(context);

  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: Text(desktopWeb ? 'Use webcam' : 'Take photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: Text(desktopWeb ? 'Choose file' : 'Choose from gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;

  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 85,
  );
  if (file == null) return null;

  final bytes = await file.readAsBytes();
  return pickedImageFromRaw(
    bytes: bytes,
    mimeType: file.mimeType,
    filename: file.name,
  );
}

/// Builds a [PickedImageBytes] from dropped, pasted, or picked bytes.
PickedImageBytes? pickedImageFromRaw({
  required Uint8List bytes,
  String? mimeType,
  String? filename,
}) {
  if (bytes.isEmpty) return null;
  final sniffed = sniffImageMime(bytes);
  var mime = (mimeType ?? '').trim().toLowerCase();
  if (mime.isEmpty || !mime.startsWith('image/')) {
    mime = sniffed ?? mimeFromFilename(filename) ?? '';
  }
  if (mime.isEmpty || !mime.startsWith('image/')) return null;
  if (mime.contains('svg')) return null;
  final extension = extensionForMime(mime);
  return PickedImageBytes(bytes: bytes, mimeType: mime, extension: extension);
}

String extensionForMime(String mime) {
  if (mime.contains('png')) return 'png';
  if (mime.contains('webp')) return 'webp';
  if (mime.contains('gif')) return 'gif';
  if (mime.contains('bmp')) return 'bmp';
  return 'jpg';
}

String? mimeFromFilename(String? filename) {
  if (filename == null) return null;
  final name = filename.toLowerCase();
  if (name.endsWith('.png')) return 'image/png';
  if (name.endsWith('.webp')) return 'image/webp';
  if (name.endsWith('.gif')) return 'image/gif';
  if (name.endsWith('.bmp')) return 'image/bmp';
  if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
  return null;
}

/// Magic-byte sniff for common raster formats.
String? sniffImageMime(Uint8List bytes) {
  if (bytes.length < 12) return null;
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
    return 'image/gif';
  }
  if (bytes[0] == 0x42 && bytes[1] == 0x4D) return 'image/bmp';
  if (bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return null;
}
