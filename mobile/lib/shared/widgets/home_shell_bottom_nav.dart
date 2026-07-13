import 'package:flutter/material.dart';

/// Shared home-shell bottom nav:
/// Search | Trips | Home | Invite | Add
class HomeShellBottomNav extends StatelessWidget {
  const HomeShellBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    this.addLabel = 'Add',
  });

  /// 0 Search, 1 Trips, 2 Home, 3 Invite, 4 Add
  final int selectedIndex;
  final Future<void> Function(int index) onSelect;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex.clamp(0, 4),
      onDestinationSelected: (index) => onSelect(index),
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.search),
          label: 'Search',
        ),
        const NavigationDestination(
          icon: Icon(Icons.luggage_outlined),
          label: 'Trips',
        ),
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_add_alt_1_outlined),
          label: 'Invite',
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
