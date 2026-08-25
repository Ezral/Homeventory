import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui';

import 'package:web/web.dart' as web;

import 'image_pick.dart';

typedef ImageIngestHitTest = bool Function(Offset global);
typedef ImageIngestAccept = void Function(List<PickedImageBytes> images);
typedef ImageIngestDrag = void Function(bool over);

class _Target {
  _Target({
    required this.containsPoint,
    required this.canPaste,
    required this.onImages,
    required this.onDragOver,
  });

  final ImageIngestHitTest containsPoint;
  final bool Function() canPaste;
  final ImageIngestAccept onImages;
  final ImageIngestDrag onDragOver;
}

class ImageIngestHandle {
  ImageIngestHandle._(this._target);

  final _Target _target;

  void cancel() {
    ImageIngestBinding._detach(_target);
  }
}

class ImageIngestBinding {
  static final List<_Target> _targets = [];
  static final JSAny _pasteCapture = true.toJS;
  static JSFunction? _paste;
  static JSFunction? _dragOver;
  static JSFunction? _dragLeave;
  static JSFunction? _drop;

  static void _attach(_Target target) {
    _targets.add(target);
    if (_targets.length == 1) _listen();
  }

  static void _detach(_Target target) {
    _targets.remove(target);
    target.onDragOver(false);
    if (_targets.isEmpty) _unlisten();
  }

  static void _listen() {
    _paste = _onPaste.toJS;
    _dragOver = _onDragOver.toJS;
    _dragLeave = _onDragLeave.toJS;
    _drop = _onDrop.toJS;
    // Capture on window so Ctrl+V is intercepted before a focused text field
    // consumes the event.
    web.window.addEventListener('paste', _paste!, _pasteCapture);
    web.document.addEventListener('dragover', _dragOver!);
    web.document.addEventListener('dragleave', _dragLeave!);
    web.document.addEventListener('drop', _drop!);
  }

  static void _unlisten() {
    if (_paste != null) {
      web.window.removeEventListener('paste', _paste!, _pasteCapture);
    }
    if (_dragOver != null) {
      web.document.removeEventListener('dragover', _dragOver!);
    }
    if (_dragLeave != null) {
      web.document.removeEventListener('dragleave', _dragLeave!);
    }
    if (_drop != null) {
      web.document.removeEventListener('drop', _drop!);
    }
    _paste = null;
    _dragOver = null;
    _dragLeave = null;
    _drop = null;
  }

  static _Target? _hit(Offset global) {
    for (var i = _targets.length - 1; i >= 0; i--) {
      final target = _targets[i];
      if (target.containsPoint(global)) return target;
    }
    return null;
  }

  static _Target? _pasteTarget() {
    for (var i = _targets.length - 1; i >= 0; i--) {
      if (_targets[i].canPaste()) return _targets[i];
    }
    return null;
  }

  static void _onPaste(web.Event event) {
    final target = _pasteTarget();
    if (target == null) return;
    final clipboard = (event as web.ClipboardEvent).clipboardData;
    if (!_transferLooksLikeImage(clipboard)) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    unawaited(_deliverImages(target, clipboard));
  }

  static void _onDragOver(web.Event event) {
    final de = event as web.DragEvent;
    final target = _hit(Offset(de.clientX.toDouble(), de.clientY.toDouble()));
    if (target == null) {
      for (final t in _targets) {
        t.onDragOver(false);
      }
      return;
    }
    event.preventDefault();
    for (final t in _targets) {
      t.onDragOver(identical(t, target));
    }
  }

  static void _onDragLeave(web.Event event) {
    final de = event as web.DragEvent;
    // Leaving the window (related target null) clears all highlights.
    if (de.relatedTarget != null) return;
    for (final t in _targets) {
      t.onDragOver(false);
    }
  }

  static void _onDrop(web.Event event) {
    final de = event as web.DragEvent;
    final target = _hit(Offset(de.clientX.toDouble(), de.clientY.toDouble()));
    for (final t in _targets) {
      t.onDragOver(false);
    }
    if (target == null) return;
    event.preventDefault();
    event.stopPropagation();
    unawaited(_deliverImages(target, de.dataTransfer));
  }

  static Future<void> _deliverImages(
    _Target target,
    web.DataTransfer? transfer,
  ) async {
    final images = await _imagesFromDataTransfer(transfer);
    if (images.isEmpty) return;
    target.onImages(images);
  }
}

ImageIngestHandle registerImageIngestTarget({
  required ImageIngestHitTest containsPoint,
  required bool Function() canPaste,
  required ImageIngestAccept onImages,
  required ImageIngestDrag onDragOver,
}) {
  final target = _Target(
    containsPoint: containsPoint,
    canPaste: canPaste,
    onImages: onImages,
    onDragOver: onDragOver,
  );
  ImageIngestBinding._attach(target);
  return ImageIngestHandle._(target);
}

bool _transferLooksLikeImage(web.DataTransfer? transfer) {
  if (transfer == null) return false;
  final items = transfer.items;
  for (var i = 0; i < items.length; i++) {
    final type = items[i].type.toLowerCase();
    if (type.startsWith('image/') && !type.contains('svg')) return true;
  }
  final files = transfer.files;
  for (var i = 0; i < files.length; i++) {
    final file = files.item(i);
    if (file == null) continue;
    final type = file.type.toLowerCase();
    if (type.startsWith('image/') && !type.contains('svg')) return true;
  }
  return false;
}

Future<List<PickedImageBytes>> _imagesFromDataTransfer(
  web.DataTransfer? transfer,
) async {
  if (transfer == null) return const [];
  final seen = <String>{};
  final out = <PickedImageBytes>[];

  Future<void> addFile(web.File? file) async {
    if (file == null) return;
    final type = file.type.toLowerCase();
    if (type.isNotEmpty && !type.startsWith('image/')) return;
    final bytes = await _readBlob(file);
    final picked = pickedImageFromRaw(
      bytes: bytes,
      mimeType: file.type,
      filename: file.name,
    );
    if (picked == null) return;
    final key = '${picked.bytes.length}:${picked.mimeType}:${file.name}';
    if (!seen.add(key)) return;
    out.add(picked);
  }

  final files = transfer.files;
  for (var i = 0; i < files.length; i++) {
    await addFile(files.item(i));
  }

  final items = transfer.items;
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    if (item.kind != 'file') continue;
    if (item.type.isNotEmpty && !item.type.startsWith('image/')) continue;
    await addFile(item.getAsFile());
  }

  return out;
}

Future<Uint8List> _readBlob(web.Blob blob) async {
  final buffer = await blob.arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}
