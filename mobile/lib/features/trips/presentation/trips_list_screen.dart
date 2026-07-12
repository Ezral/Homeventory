import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../homes/presentation/homes_providers.dart';
import 'trips_providers.dart';

class TripsListScreen extends ConsumerWidget {
  const TripsListScreen({super.key, required this.homeId});

  final String homeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripsListProvider(homeId));
    final homeAsync = ref.watch(homeProvider(homeId));
    final canEdit = homeAsync.maybeWhen(
      data: (home) => home.myRole?.canEditInventory ?? false,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Trips')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _createTrip(context, ref),
              backgroundColor: AppColors.moss,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Create trip'),
            )
          : null,
      body: tripsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(tripsListProvider(homeId)),
        ),
        data: (trips) {
          if (trips.isEmpty) {
            return EmptyState(
              icon: Icons.luggage_outlined,
              title: 'No trips yet',
              message: canEdit
                  ? 'Create a trip to assign luggage and pack items.'
                  : 'No trips have been created for this home.',
              actionLabel: canEdit ? 'Create trip' : null,
              onAction: canEdit ? () => _createTrip(context, ref) : null,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(tripsListProvider(homeId)),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              itemCount: trips.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final trip = trips[index];
                return SoftTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.mossSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.luggage_outlined,
                      color: AppColors.mossDeep,
                    ),
                  ),
                  title: trip.name,
                  subtitle: trip.status.label,
                  onTap: () => context.push('/homes/$homeId/trips/${trip.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _createTrip(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create trip'),
              content: TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Name',
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.isEmpty) {
                      setDialogState(() => errorText = 'Name is required');
                      return;
                    }
                    Navigator.pop(context, value);
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (name == null || !context.mounted) return;

    try {
      final trip = await ref
          .read(tripsRepositoryProvider)
          .createTrip(homeId: homeId, name: name);
      ref.invalidate(tripsListProvider(homeId));
      if (context.mounted) {
        context.push('/homes/$homeId/trips/${trip.id}');
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
