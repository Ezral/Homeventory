import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/home.dart';
import '../../../shared/widgets/app_widgets.dart';
import 'homes_providers.dart';

/// App settings: archive/restore homes (and later currency / notifications).
class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleAsync = ref.watch(homesListProvider);
    final archivedAsync = ref.watch(hiddenHomesListProvider);

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
            Text('Homes', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Archive a home to remove it from your homes list. '
              'Inventory stays saved — you can restore it anytime. '
              'Only the home owner can archive or restore a home.',
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
                      _HomeArchiveTile(
                        home: home,
                        archived: false,
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
            const SectionLabel('Reminders'),
            const SizedBox(height: 6),
            Text(
              'Cleanup alarms and refill reminders live on each home. '
              'Android can notify in the background; the browser list is the same source of truth.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            visibleAsync.maybeWhen(
              data: (homes) {
                if (homes.isEmpty) {
                  return Text(
                    'Open a home to add reminders.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }
                return Column(
                  children: [
                    for (final home in homes) ...[
                      SoftTile(
                        leading: const Icon(
                          Icons.notifications_outlined,
                          color: AppColors.mossDeep,
                        ),
                        title: home.name,
                        subtitle: 'Alarms and refill reminders',
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            context.push('/homes/${home.id}/reminders'),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            const SectionLabel('Archived homes'),
            const SizedBox(height: 10),
            archivedAsync.when(
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
                    'No archived homes.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }
                return Column(
                  children: [
                    for (final home in homes) ...[
                      _HomeArchiveTile(
                        home: home,
                        archived: true,
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

class _HomeArchiveTile extends ConsumerWidget {
  const _HomeArchiveTile({
    required this.home,
    required this.archived,
    required this.onChanged,
  });

  final Home home;
  final bool archived;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canArchive = home.myRole?.isOwner ?? false;

    return SoftTile(
      leading: Icon(
        archived ? Icons.archive_outlined : Icons.home_outlined,
        color: AppColors.mossDeep,
      ),
      title: home.name,
      subtitle: [
        if (home.myRole != null) home.myRole!.label,
        if (archived) 'Archived',
      ].join(' · '),
      trailing: canArchive
          ? TextButton(
              onPressed: () =>
                  archived ? _unarchive(context, ref) : _archive(context, ref),
              child: Text(archived ? 'Restore' : 'Archive'),
            )
          : Tooltip(
              message: 'Only the home owner can archive homes',
              child: Text(
                archived ? 'Archived' : '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
    );
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive ${home.name}?'),
        content: const Text(
          'It will disappear from your homes list. '
          'You can restore it later under Archived homes in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await ref.read(homesRepositoryProvider).archiveHome(home.id);
      ref.invalidate(activeHomeIdProvider);
      onChanged();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${home.name} is archived')));
      // If we were inside that home, go back to the homes list.
      final loc = GoRouterState.of(context).uri.path;
      if (loc.contains(home.id)) {
        context.go('/');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _unarchive(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(homesRepositoryProvider).unarchiveHome(home.id);
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${home.name} is restored')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}
