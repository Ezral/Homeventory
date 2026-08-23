import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/web_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/entity_thumbnail.dart';
import '../../../shared/widgets/user_menu_button.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../rooms/presentation/rooms_providers.dart';
import 'homes_providers.dart';

class HomesScreen extends ConsumerWidget {
  const HomesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homes = ref.watch(homesListProvider);
    final profile = ref.watch(currentProfileProvider);
    final desktop = isWebDesktopLayout(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your homes'),
        actions: [
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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => context.push('/homes/join'),
                            icon: const Icon(Icons.qr_code_2),
                            label: const Text('Join with invite'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (list.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.home_work_outlined,
                      title: 'No homes yet',
                      message:
                          'Create your first Home, or join one with an invite link, QR, or short code.',
                    ),
                  )
                else if (desktop)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 320,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 1.4,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final home = list[index];
                          final thumbsAsync = ref.watch(
                            entityThumbnailsProvider(
                              (
                                homeId: home.id,
                                entityType: 'HOME',
                                idsKey: home.id,
                              ),
                            ),
                          );
                          final thumbUrl = thumbsAsync.maybeWhen(
                            data: (m) => m[home.id],
                            orElse: () => null,
                          );
                          return Material(
                            color: AppColors.paper,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                await ref
                                    .read(activeHomeIdProvider.notifier)
                                    .setActive(home.id);
                                if (context.mounted) {
                                  context.push('/homes/${home.id}');
                                }
                              },
                              child: Ink(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.line),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      EntityThumbnail(
                                        imageUrl: thumbUrl,
                                        fallback: Icons.home_outlined,
                                      ),
                                      const Spacer(),
                                      Text(
                                        home.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        [
                                          if (home.myRole != null)
                                            home.myRole!.label,
                                          if (home.addressText != null)
                                            home.addressText!,
                                        ].join(' · '),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: list.length,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    sliver: SliverList.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final home = list[index];
                        final thumbsAsync = ref.watch(
                          entityThumbnailsProvider(
                            (
                              homeId: home.id,
                              entityType: 'HOME',
                              idsKey: home.id,
                            ),
                          ),
                        );
                        final thumbUrl = thumbsAsync.maybeWhen(
                          data: (m) => m[home.id],
                          orElse: () => null,
                        );
                        return SoftTile(
                          leading: EntityThumbnail(
                            imageUrl: thumbUrl,
                            fallback: Icons.home_outlined,
                          ),
                          title: home.name,
                          subtitle: [
                            if (home.myRole != null) home.myRole!.label,
                            if (home.addressText != null) home.addressText!,
                          ].join(' · '),
                          onTap: () async {
                            await ref
                                .read(activeHomeIdProvider.notifier)
                                .setActive(home.id);
                            if (context.mounted) {
                              context.push('/homes/${home.id}');
                            }
                          },
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
