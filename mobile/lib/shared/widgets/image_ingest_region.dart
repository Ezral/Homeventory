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
  });

  final ValueChanged<List<PickedImageBytes>> onImages;
  final Widget child;
  final bool enabled;
  final bool showHint;
  final bool compact;

  @override
  State<ImageIngestRegion> createState() => _ImageIngestRegionState();
}

class _ImageIngestRegionState extends State<ImageIngestRegion> {
  ImageIngestHandle? _handle;
  bool _hovered = false;
  bool _focused = false;
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
    if (!widget.enabled || !mounted) return false;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return false;
    final origin = box.localToGlobal(Offset.zero);
    return (origin & box.size).contains(global);
  }

  bool _canPaste() {
    if (!widget.enabled || !mounted) return false;
    if (_textFieldHasFocus) return false;
    return _hovered || _focused || _dragOver;
  }

  bool get _textFieldHasFocus {
    var node = FocusManager.instance.primaryFocus;
    while (node != null) {
      if (node.context?.widget is EditableText) return true;
      node = node.parent;
    }
    return false;
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
                  : 'Drop an image here, or paste with Ctrl+V',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: highlight ? AppColors.moss : AppColors.inkMuted,
              ),
            ),
          ),
        ],
      );
    }

    child = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.compact ? 10 : 12),
        border: highlight ? Border.all(color: AppColors.moss, width: 2) : null,
        color: highlight ? AppColors.mossSoft.withValues(alpha: 0.45) : null,
      ),
      child: child,
    );

    return Focus(
      canRequestFocus: widget.enabled && kIsWeb,
      onFocusChange: (focused) {
        if (mounted) setState(() => _focused = focused);
      },
      child: MouseRegion(
        onEnter: (_) {
          if (mounted) setState(() => _hovered = true);
        },
        onExit: (_) {
          if (mounted) setState(() => _hovered = false);
        },
        child: child,
      ),
    );
  }
}
