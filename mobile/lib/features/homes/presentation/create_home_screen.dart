import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'homes_providers.dart';

class CreateHomeScreen extends ConsumerStatefulWidget {
  const CreateHomeScreen({super.key});

  @override
  ConsumerState<CreateHomeScreen> createState() => _CreateHomeScreenState();
}

class _CreateHomeScreenState extends ConsumerState<CreateHomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final home = await ref.read(homesRepositoryProvider).createHome(
            name: _name.text,
            description: _description.text,
            addressText: _address.text,
          );
      ref.invalidate(homesListProvider);
      if (mounted) context.go('/homes/${home.id}');
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
      appBar: AppBar(title: const Text('New home')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Home name',
                hintText: 'Bangkok Apartment',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: 'Address (optional)',
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Creating…' : 'Create home'),
            ),
          ],
        ),
      ),
    );
  }
}
