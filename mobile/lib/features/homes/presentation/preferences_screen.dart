import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/home.dart';
import '../../../shared/widgets/app_widgets.dart';
import 'homes_providers.dart';

/// App settings: hide/show homes (and later currency / notifications).
class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleAsync = ref.watch(homesListProvider);
    final hiddenAsync = ref.watch(hiddenHomesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homesListProvider);
          ref.invalidate(hiddenHomesListProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Text(
              'Homes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Hide a home to remove it from your homes list. '
              'Inventory stays saved — you can show it again anytime. '
              'Only the home owner can hide or restore a home.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            const SectionLabel('Visible homes'),
            const SizedBox(height: 10),
            visibleAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(homesListProvider),
              ),
              data: (homes) {
                if (homes.isEmpty) {
                  return Text(
                    'No visible homes.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }
                return Column(
                  children: [
                    for (final home in homes) ...[
                      _HomeHideTile(
                        home: home,
                        hidden: false,
                        onChanged: () {
                          ref.invalidate(homesListProvider);
                          ref.invalidate(hiddenHomesListProvider);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            const SectionLabel('Hidden homes'),
            const SizedBox(height: 10),
            hiddenAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(hiddenHomesListProvider),
              ),
              data: (homes) {
                if (homes.isEmpty) {
                  return Text(
                    'No hidden homes.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }
                return Column(
                  children: [
                    for (final home in homes) ...[
                      _HomeHideTile(
                        home: home,
                        hidden: true,
                        onChanged: () {
                          ref.invalidate(homesListProvider);
                          ref.invalidate(hiddenHomesListProvider);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHideTile extends ConsumerWidget {
  const _HomeHideTile({
    required this.home,
    required this.hidden,
    required this.onChanged,
  });

  final Home home;
  final bool hidden;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canHide = home.myRole?.isOwner ?? false;

    return SoftTile(
      leading: Icon(
        hidden ? Icons.visibility_off_outlined : Icons.home_outlined,
        color: AppColors.mossDeep,
      ),
      title: home.name,
      subtitle: [
        if (home.myRole != null) home.myRole!.label,
        if (hidden) 'Hidden',
      ].join(' · '),
      trailing: canHide
          ? TextButton(
              onPressed: () => hidden
                  ? _unhide(context, ref)
                  : _hide(context, ref),
              child: Text(hidden ? 'Show' : 'Hide'),
            )
          : Tooltip(
              message: 'Only the home owner can hide homes',
              child: Text(
                hidden ? 'Hidden' : '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
    );
  }

  Future<void> _hide(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hide ${home.name}?'),
        content: const Text(
          'It will disappear from your homes list. '
          'You can restore it later under Hidden homes in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hide'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await ref.read(homesRepositoryProvider).hideHome(home.id);
      ref.invalidate(activeHomeIdProvider);
      onChanged();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${home.name} is now hidden')),
      );
      // If we were inside that home, go back to the homes list.
      final loc = GoRouterState.of(context).uri.path;
      if (loc.contains(home.id)) {
        context.go('/');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _unhide(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(homesRepositoryProvider).unhideHome(home.id);
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${home.name} is visible again')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }
}
