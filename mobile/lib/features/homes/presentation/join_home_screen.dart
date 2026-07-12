import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'homes_providers.dart';

class JoinHomeScreen extends ConsumerStatefulWidget {
  const JoinHomeScreen({super.key});

  @override
  ConsumerState<JoinHomeScreen> createState() => _JoinHomeScreenState();
}

class _JoinHomeScreenState extends ConsumerState<JoinHomeScreen> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    setState(() => _busy = true);
    try {
      // Backend accepts the raw invite token (>=32 chars) or the short code.
      final homeId =
          await ref.read(homesRepositoryProvider).acceptInvitation(value);
      ref.invalidate(homesListProvider);
      if (mounted) context.go('/homes/$homeId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join a home')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Paste an invite token or short code from a home owner or admin.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Invite token or short code',
              hintText: 'Paste token or code…',
            ),
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _join,
            child: Text(_busy ? 'Joining…' : 'Accept invitation'),
          ),
        ],
      ),
    );
  }
}
