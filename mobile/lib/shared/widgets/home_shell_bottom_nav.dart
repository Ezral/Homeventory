import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom-nav indexes: Search | Schedule | Home | Trips | Add
abstract final class HomeShellNav {
  static const search = 0;
  static const schedule = 1;
  static const home = 2;
  static const trips = 3;
  static const add = 4;
}

/// Shared home-shell bottom nav.
class HomeShellBottomNav extends StatelessWidget {
  const HomeShellBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    this.addLabel = 'Add',
  });

  final int selectedIndex;
  final Future<void> Function(int index) onSelect;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex.clamp(0, 4),
      onDestinationSelected: (index) => onSelect(index),
      destinations: [
        const NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
        const NavigationDestination(
          icon: Icon(Icons.schedule),
          selectedIcon: Icon(Icons.schedule),
          label: 'Schedule',
        ),
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        const NavigationDestination(
          icon: Icon(Icons.luggage_outlined),
          label: 'Trips',
        ),
        NavigationDestination(
          icon: const Icon(Icons.add_circle_outline),
          selectedIcon: const Icon(Icons.add_circle),
          label: addLabel,
        ),
      ],
    );
  }
}

Future<void> handleHomeShellSelect({
  required BuildContext context,
  required String homeId,
  required int index,
  required bool canEdit,
  Future<void> Function()? onAdd,
  String addDeniedMessage = 'You do not have permission to add.',
}) async {
  switch (index) {
    case HomeShellNav.search:
      context.go('/homes/$homeId/search');
    case HomeShellNav.schedule:
      context.go('/homes/$homeId/schedule');
    case HomeShellNav.home:
      context.go('/homes/$homeId');
    case HomeShellNav.trips:
      context.go('/homes/$homeId/trips');
    case HomeShellNav.add:
      if (onAdd == null) return;
      if (!canEdit) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(addDeniedMessage)));
        return;
      }
      await onAdd();
  }
}
