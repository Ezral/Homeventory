import 'package:go_router/go_router.dart';

/// Parent locations for a reminder deep link so Android back walks
/// item → room → home → homes list instead of leaving the app immediately.
List<String> reminderNavigationStack(String path) {
  final uri = Uri.tryParse(path);
  if (uri == null) return const ['/'];
  final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (parts.length >= 2 && parts[0] == 'homes') {
    final homeId = parts[1];
    final stack = <String>['/', '/homes/$homeId'];
    if (parts.length >= 4 && parts[2] == 'rooms') {
      final roomId = parts[3];
      stack.add('/homes/$homeId/rooms/$roomId');
      if (parts.length >= 6 && parts[4] == 'nodes') {
        final nodeId = parts[5];
        if (parts.length >= 7 && parts[6] == 'details') {
          stack.add('/homes/$homeId/rooms/$roomId/nodes/$nodeId/details');
        } else {
          stack.add('/homes/$homeId/rooms/$roomId/nodes/$nodeId');
        }
      }
    } else if (parts.length >= 3 && parts[2] == 'schedule') {
      stack.add('/homes/$homeId/schedule');
    }
    return stack;
  }
  if (path.startsWith('/')) return [path];
  return const ['/'];
}

/// Opens [path] with a real Homeventory back stack.
void openReminderDestination(GoRouter router, String path) {
  final stack = reminderNavigationStack(path);
  router.go(stack.first);
  for (final loc in stack.skip(1)) {
    router.push(loc);
  }
}
