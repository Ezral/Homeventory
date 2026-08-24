import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SelectionActionBar extends StatelessWidget {
  const SelectionActionBar({
    super.key,
    required this.count,
    required this.onClear,
    required this.onMove,
    required this.onDispose,
    required this.onPack,
  });

  final int count;
  final VoidCallback onClear;
  final VoidCallback onMove;
  final VoidCallback onDispose;
  final VoidCallback onPack;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: AppColors.paperElevated,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Clear selection',
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
              Text(
                '$count selected',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onMove,
                icon: const Icon(Icons.drive_file_move_outlined, size: 18),
                label: const Text('Move'),
              ),
              TextButton.icon(
                onPressed: onPack,
                icon: const Icon(Icons.luggage_outlined, size: 18),
                label: const Text('Pack'),
              ),
              TextButton.icon(
                onPressed: onDispose,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Dispose'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
