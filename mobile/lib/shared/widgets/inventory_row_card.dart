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
    this.onLongPress,
    this.selected = false,
    this.dimmed = false,
    this.height = 112,
    this.showCheckbox = false,
    this.checked = false,
    this.onToggleChecked,
  });

  final String title;
  final String? subtitle;
  final String? imageUrl;
  final IconData fallbackIcon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool dimmed;
  final double height;
  final bool showCheckbox;
  final bool checked;
  final VoidCallback? onToggleChecked;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);

    return Material(
      color: AppColors.paperElevated,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: radius,
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 1,
                    child: _RowImage(
                      imageUrl: imageUrl,
                      fallbackIcon: fallbackIcon,
                      showCheckbox: showCheckbox,
                      checked: checked,
                      onToggleChecked: onToggleChecked,
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
                                  style: Theme.of(context).textTheme.titleMedium
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
              // Border sits above the image + text so selection frames the full card.
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: selected ? AppColors.moss : AppColors.line,
                      width: selected ? 2.5 : 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowImage extends StatelessWidget {
  const _RowImage({
    required this.imageUrl,
    required this.fallbackIcon,
    this.showCheckbox = false,
    this.checked = false,
    this.onToggleChecked,
  });

  final String? imageUrl;
  final IconData fallbackIcon;
  final bool showCheckbox;
  final bool checked;
  final VoidCallback? onToggleChecked;

  static const _previewSize = 280.0;

  @override
  Widget build(BuildContext context) {
    final image = imageUrl == null
        ? ColoredBox(
            color: AppColors.mossSoft,
            child: Center(
              child: Icon(fallbackIcon, color: AppColors.mossDeep, size: 36),
            ),
          )
        : Image.network(
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

    Widget content = image;
    if (imageUrl != null) {
      // Hover (web/desktop) shows a larger preview of the same photo.
      content = Tooltip(
        waitDuration: const Duration(milliseconds: 280),
        showDuration: const Duration(seconds: 12),
        preferBelow: true,
        verticalOffset: 12,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.paperElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        richMessage: WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: _previewSize,
              height: _previewSize,
              child: Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: AppColors.mossSoft,
                  child: Icon(
                    fallbackIcon,
                    color: AppColors.mossDeep,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
        ),
        child: image,
      );
    }

    if (!showCheckbox) return content;

    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        Positioned(
          top: 6,
          left: 6,
          child: Material(
            color: Colors.white,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            child: SizedBox(
              width: 28,
              height: 28,
              child: Checkbox(
                value: checked,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: onToggleChecked == null
                    ? null
                    : (_) => onToggleChecked!(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
