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
                final subtitle = [
                  trip.status.label,
                  if (trip.luggageAllowanceKg != null)
                    '${_fmtKg(trip.luggageAllowanceKg!)} kg allowance',
                ].join(' · ');
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
                  subtitle: subtitle,
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
    final nameController = TextEditingController();
    final allowanceController = TextEditingController();
    final created = await showDialog<({String name, double? allowance})>(
      context: context,
      builder: (context) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create trip'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      errorText: errorText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: allowanceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Luggage allowance (kg, optional)',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = nameController.text.trim();
                    if (value.isEmpty) {
                      setDialogState(() => errorText = 'Name is required');
                      return;
                    }
                    final allowanceText = allowanceController.text.trim();
                    final allowance = allowanceText.isEmpty
                        ? null
                        : double.tryParse(allowanceText);
                    if (allowanceText.isNotEmpty && allowance == null) {
                      setDialogState(
                        () => errorText = 'Allowance must be a number',
                      );
                      return;
                    }
                    Navigator.pop(
                      context,
                      (name: value, allowance: allowance),
                    );
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
    nameController.dispose();
    allowanceController.dispose();
    if (created == null || !context.mounted) return;

    try {
      final trip = await ref.read(tripsRepositoryProvider).createTrip(
            homeId: homeId,
            name: created.name,
            luggageAllowanceKg: created.allowance,
          );
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

String _fmtKg(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2);
}
