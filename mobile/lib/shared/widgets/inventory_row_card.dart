import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Inventory list row: image takes the left third; details fill the rest.
///
/// Fixed height keeps rows even; the height is sized for title + detail lines.
class InventoryRowCard extends StatelessWidget {
  const InventoryRowCard({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    required this.fallbackIcon,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.dimmed = false,
    this.height = 112,
  });

  final String title;
  final String? subtitle;
  final String? imageUrl;
  final IconData fallbackIcon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final bool dimmed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paperElevated,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.moss : AppColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 1,
                  child: _HalfImage(
                    imageUrl: imageUrl,
                    fallbackIcon: fallbackIcon,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: dimmed
                                          ? AppColors.inkMuted
                                          : AppColors.ink,
                                      fontWeight: FontWeight.w600,
                                      height: 1.25,
                                    ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 4),
                                Expanded(
                                  child: Text(
                                    subtitle!,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.inkMuted,
                                          height: 1.3,
                                        ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        ?trailing,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HalfImage extends StatelessWidget {
  const _HalfImage({
    required this.imageUrl,
    required this.fallbackIcon,
  });

  final String? imageUrl;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) {
      return ColoredBox(
        color: AppColors.mossSoft,
        child: Center(
          child: Icon(fallbackIcon, color: AppColors.mossDeep, size: 36),
        ),
      );
    }
    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => ColoredBox(
        color: AppColors.mossSoft,
        child: Center(
          child: Icon(fallbackIcon, color: AppColors.mossDeep, size: 36),
        ),
      ),
    );
  }
}
