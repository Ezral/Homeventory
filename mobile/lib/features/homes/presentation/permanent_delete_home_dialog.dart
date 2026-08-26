import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Confirms irreversible deletion of an archived home by requiring the name.
Future<bool> showPermanentDeleteHomeDialog({
  required BuildContext context,
  required String homeName,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => PermanentDeleteHomeDialog(homeName: homeName),
  );
  return result == true;
}

class PermanentDeleteHomeDialog extends StatefulWidget {
  const PermanentDeleteHomeDialog({super.key, required this.homeName});

  final String homeName;

  @override
  State<PermanentDeleteHomeDialog> createState() =>
      _PermanentDeleteHomeDialogState();
}

class _PermanentDeleteHomeDialogState extends State<PermanentDeleteHomeDialog> {
  final _controller = TextEditingController();

  bool get _nameMatches =>
      _controller.text.trim().toLowerCase() ==
      widget.homeName.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Permanently delete ${widget.homeName}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This cannot be undone. Rooms, inventory, photos, trips, '
            'and schedules for this home will be erased.',
          ),
          const SizedBox(height: 16),
          Text(
            'Type ${widget.homeName} to confirm.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Home name'),
            onSubmitted: (_) {
              if (_nameMatches) Navigator.pop(context, true);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _nameMatches ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text('Delete forever'),
        ),
      ],
    );
  }
}
