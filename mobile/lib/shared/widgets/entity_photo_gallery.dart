import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class GalleryPhoto {
  const GalleryPhoto({required this.id, this.url});

  final String id;
  final String? url;
}

/// Horizontal photo strip. Editors can delete from the overlay or the
/// enlarged preview.
class EntityPhotoGallery extends StatelessWidget {
  const EntityPhotoGallery({
    super.key,
    required this.images,
    this.canEdit = false,
    this.onDelete,
    this.confirmBeforeDelete = true,
    this.emptyLabel = 'No photos yet.',
    this.size = 120,
  });

  final List<GalleryPhoto> images;
  final bool canEdit;
  final Future<void> Function(String id)? onDelete;
  final bool confirmBeforeDelete;
  final String emptyLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return Text(
        emptyLabel,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final photo = images[index];
          return _PhotoThumb(
            photo: photo,
            size: size,
            canEdit: canEdit,
            onDelete: onDelete,
            confirmBeforeDelete: confirmBeforeDelete,
          );
        },
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({
    required this.photo,
    required this.size,
    required this.canEdit,
    required this.onDelete,
    required this.confirmBeforeDelete,
  });

  final GalleryPhoto photo;
  final double size;
  final bool canEdit;
  final Future<void> Function(String id)? onDelete;
  final bool confirmBeforeDelete;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Material(
          color: AppColors.mossSoft,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openPreview(context),
            child: SizedBox(
              width: size,
              height: size,
              child: photo.url == null
                  ? const Icon(Icons.broken_image)
                  : Image.network(
                      photo.url!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image),
                    ),
            ),
          ),
        ),
        if (canEdit && onDelete != null)
          Positioned(
            top: 4,
            right: 4,
            child: _DeletePhotoButton(
              onPressed: () => _confirmAndDelete(context),
            ),
          ),
      ],
    );
  }

  Future<void> _openPreview(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: photo.url == null
                        ? const ColoredBox(
                            color: AppColors.mossSoft,
                            child: Icon(Icons.broken_image, size: 48),
                          )
                        : Image.network(
                            photo.url!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const ColoredBox(
                              color: AppColors.mossSoft,
                              child: Icon(Icons.broken_image, size: 48),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  children: [
                    if (canEdit && onDelete != null)
                      TextButton.icon(
                        onPressed: () async {
                          final deleted =
                              await _confirmAndDelete(dialogContext);
                          if (deleted && dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete photo'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                        ),
                      ),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmAndDelete(BuildContext context) async {
    if (onDelete == null) return false;
    if (confirmBeforeDelete) {
      final confirmed = await confirmDeletePhoto(context);
      if (!confirmed) return false;
    }
    await onDelete!(photo.id);
    return true;
  }
}

class _DeletePhotoButton extends StatelessWidget {
  const _DeletePhotoButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: 'Delete photo',
        iconSize: 18,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        color: Colors.white,
        icon: const Icon(Icons.close),
        onPressed: onPressed,
      ),
    );
  }
}

Future<bool> confirmDeletePhoto(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text('This photo will be removed from the item.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
  return result == true;
}
