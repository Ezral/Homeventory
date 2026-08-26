import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/web_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/home.dart';
import '../../../shared/providers/supabase_provider.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/user_menu_button.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../rooms/presentation/rooms_providers.dart';
import 'homes_providers.dart';

class HomesScreen extends ConsumerStatefulWidget {
  const HomesScreen({super.key});

  @override
  ConsumerState<HomesScreen> createState() => _HomesScreenState();
}

class _HomesScreenState extends ConsumerState<HomesScreen> {
  bool _checkedPendingNav = false;
  bool _installing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checkedPendingNav) return;
    _checkedPendingNav = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final pending = await ref
          .read(localSessionStoreProvider)
          .readPendingNav();
      if (!mounted || pending == null || !pending.startsWith('/')) return;
      await ref.read(localSessionStoreProvider).clearPendingNav();
      if (mounted) context.go(pending);
    });
  }

  Future<void> _loadDemoStudio() async {
    if (_installing) return;
    setState(() => _installing = true);
    final status = ValueNotifier('Creating Bangkok studio…');
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: ValueListenableBuilder<String>(
              valueListenable: status,
              builder: (context, text, _) {
                return Row(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(width: 20),
                    Expanded(child: Text(text)),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
    try {
      final home = await ref
          .read(demoStudioInstallerProvider)
          .install(onProgress: (text) => status.value = text);
      ref.invalidate(homesListProvider);
      await ref.read(activeHomeIdProvider.notifier).setActive(home.id);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      context.go('/homes/${home.id}');
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      status.dispose();
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final homes = ref.watch(homesListProvider);
    final profile = ref.watch(currentProfileProvider);
    final desktop = isWebDesktopLayout(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your homes'),
        actions: [
          if (desktop)
            TextButton.icon(
              onPressed: _installing ? null : _loadDemoStudio,
              icon: const Icon(Icons.apartment_outlined),
              label: const Text('Demo studio'),
            )
          else
            IconButton(
              tooltip: 'Load demo studio',
              onPressed: _installing ? null : _loadDemoStudio,
              icon: const Icon(Icons.apartment_outlined),
            ),
          if (!desktop)
            IconButton(
              tooltip: 'Join with invite',
              onPressed: () => context.push('/homes/join'),
              icon: const Icon(Icons.qr_code_2),
            ),
          if (!desktop) const UserMenuButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/homes/new'),
        backgroundColor: AppColors.moss,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_home_outlined),
        label: const Text('New home'),
      ),
      body: homes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(homesListProvider),
        ),
        data: (list) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(homesListProvider),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: profile.when(
                      data: (p) => Text(
                        'Hajimemashite, ${p?.greetingName ?? 'there'}.',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                if (list.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.home_work_outlined,
                      title: 'No homes yet',
                      message:
                          'Load the Bangkok demo studio, create a home, or join with an invite.',
                      actionLabel: _installing
                          ? 'Loading…'
                          : 'Load demo studio',
                      onAction: _installing ? null : _loadDemoStudio,
                    ),
                  )
                else if (desktop)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 300,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.95,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final home = list[index];
                        return _HomeCoverCard(home: home);
                      }, childCount: list.length),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    sliver: SliverList.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return SizedBox(
                          height: 200,
                          child: _HomeCoverCard(home: list[index]),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HomeCoverCard extends ConsumerWidget {
  const _HomeCoverCard({required this.home});

  final Home home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbsAsync = ref.watch(
      entityThumbnailsProvider((
        homeId: home.id,
        entityType: 'HOME',
        idsKey: home.id,
      )),
    );
    final thumbUrl = thumbsAsync.maybeWhen(
      data: (m) => m[home.id],
      orElse: () => null,
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await ref.read(activeHomeIdProvider.notifier).setActive(home.id);
          if (context.mounted) {
            context.push('/homes/${home.id}');
          }
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: thumbUrl == null
                    ? const ColoredBox(
                        color: AppColors.mossSoft,
                        child: Center(
                          child: Icon(
                            Icons.home_outlined,
                            size: 40,
                            color: AppColors.mossDeep,
                          ),
                        ),
                      )
                    : Image.network(
                        thumbUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: AppColors.mossSoft,
                          child: Center(
                            child: Icon(
                              Icons.home_outlined,
                              size: 40,
                              color: AppColors.mossDeep,
                            ),
                          ),
                        ),
                      ),
              ),
              ColoredBox(
                color: AppColors.mossDeep,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Text(
                    home.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
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
