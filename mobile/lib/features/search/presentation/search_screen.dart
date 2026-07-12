import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../rooms/presentation/rooms_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, required this.homeId});

  final String homeId;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _query.trim().isEmpty
        ? null
        : ref.watch(
            inventorySearchProvider(
              (homeId: widget.homeId, query: _query),
            ),
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Find items, furniture, bags…',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: results == null
                ? const EmptyState(
                    icon: Icons.search,
                    title: 'Search this home',
                    message:
                        'Look up anything by name across rooms and nested containers.',
                  )
                : results.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => ErrorView(message: e.toString()),
                    data: (nodes) {
                      if (nodes.isEmpty) {
                        return const EmptyState(
                          title: 'No matches',
                          message: 'Try a different name or spelling.',
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: nodes.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final node = nodes[index];
                          return SoftTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.mossSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.inventory_2_outlined,
                                color: AppColors.mossDeep,
                              ),
                            ),
                            title: node.name,
                            subtitle: node.kindLabel,
                            onTap: () {
                              if (node.isContainer) {
                                context.push(
                                  '/homes/${widget.homeId}/rooms/${node.roomId}/nodes/${node.id}',
                                );
                              } else {
                                context.push(
                                  '/homes/${widget.homeId}/rooms/${node.roomId}/nodes/${node.id}/details',
                                );
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
