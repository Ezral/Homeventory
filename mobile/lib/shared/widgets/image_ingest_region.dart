import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../utils/image_ingest_binding_stub.dart'
    if (dart.library.js_interop) '../utils/image_ingest_binding_web.dart';
import '../utils/image_pick.dart';

/// Web desktop: drop files or Ctrl+V an image onto [child].
///
/// Native apps keep the camera / gallery picker only.
class ImageIngestRegion extends StatefulWidget {
  const ImageIngestRegion({
    super.key,
    required this.onImages,
    required this.child,
    this.enabled = true,
    this.showHint = false,
    this.compact = false,
    this.listenForPaste = true,
    this.listenForDrop = true,
  });

  final ValueChanged<List<PickedImageBytes>> onImages;
  final Widget child;
  final bool enabled;
  final bool showHint;
  final bool compact;

  /// When false, this region only accepts dropped files (used on bulk-add
  /// rows so table-level Ctrl+V can target checked rows).
  final bool listenForPaste;

  /// When false, this region is skipped for hit-testing drops.
  final bool listenForDrop;

  @override
  State<ImageIngestRegion> createState() => _ImageIngestRegionState();
}

class _ImageIngestRegionState extends State<ImageIngestRegion> {
  ImageIngestHandle? _handle;
  bool _dragOver = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _handle = registerImageIngestTarget(
        containsPoint: _containsPoint,
        canPaste: _canPaste,
        onImages: _emit,
        onDragOver: _setDragOver,
      );
    }
  }

  @override
  void dispose() {
    _handle?.cancel();
    super.dispose();
  }

  bool _containsPoint(Offset global) {
    if (!widget.enabled || !widget.listenForDrop || !mounted) return false;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return false;
    final origin = box.localToGlobal(Offset.zero);
    return (origin & box.size).contains(global);
  }

  bool _canPaste() {
    return widget.enabled && widget.listenForPaste && mounted;
  }

  void _setDragOver(bool over) {
    if (_dragOver == over || !mounted) return;
    setState(() => _dragOver = over);
  }

  void _emit(List<PickedImageBytes> images) {
    if (!widget.enabled || images.isEmpty || !mounted) return;
    widget.onImages(images);
  }

  @override
  Widget build(BuildContext context) {
    final highlight = widget.enabled && _dragOver;
    Widget child = widget.child;
    if (widget.showHint && kIsWeb) {
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              highlight
                  ? 'Drop to add'
                  : widget.listenForPaste
                  ? 'Drop an image here, or paste with Ctrl+V'
                  : 'Drop an image here',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: highlight ? AppColors.moss : AppColors.inkMuted,
              ),
            ),
          ),
        ],
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.compact ? 10 : 12),
        border: highlight ? Border.all(color: AppColors.moss, width: 2) : null,
        color: highlight ? AppColors.mossSoft.withValues(alpha: 0.45) : null,
      ),
      child: child,
    );
  }
}
