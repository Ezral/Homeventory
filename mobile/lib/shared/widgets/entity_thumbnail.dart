import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 44×44 leading thumbnail; falls back to [fallback] when [imageUrl] is null.
class EntityThumbnail extends StatelessWidget {
  const EntityThumbnail({
    super.key,
    this.imageUrl,
    required this.fallback,
  });

  final String? imageUrl;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 44,
        height: 44,
        child: imageUrl == null
            ? ColoredBox(
                color: AppColors.mossSoft,
                child: Icon(fallback, color: AppColors.mossDeep),
              )
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: AppColors.mossSoft,
                  child: Icon(fallback, color: AppColors.mossDeep),
                ),
              ),
      ),
    );
  }
}
