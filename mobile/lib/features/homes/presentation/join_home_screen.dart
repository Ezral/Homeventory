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
      // Accept either raw token or short code — backend RPC expects token.
      // Short-code acceptance can be added as a separate RPC later; for now
      // users paste the invite token from the share sheet.
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
            'Paste an invite token from a home owner or admin.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Invite token',
              hintText: 'Paste token…',
            ),
            minLines: 2,
            maxLines: 4,
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
