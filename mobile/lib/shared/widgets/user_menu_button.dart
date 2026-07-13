import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../models/profile.dart';

/// Top-right avatar menu: identity, Preferences, Sign out.
class UserMenuButton extends ConsumerWidget {
  const UserMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return profileAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => IconButton(
        tooltip: 'Account',
        onPressed: () => _openMenu(context, ref, null),
        icon: const Icon(Icons.account_circle_outlined),
      ),
      data: (profile) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: IconButton(
          tooltip: 'Account',
          onPressed: () => _openMenu(context, ref, profile),
          icon: _Avatar(profile: profile),
        ),
      ),
    );
  }

  Future<void> _openMenu(
    BuildContext context,
    WidgetRef ref,
    Profile? profile,
  ) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    final position = box != null && overlay != null
        ? RelativeRect.fromRect(
            Rect.fromPoints(
              box.localToGlobal(Offset.zero, ancestor: overlay),
              box.localToGlobal(
                box.size.bottomRight(Offset.zero),
                ancestor: overlay,
              ),
            ),
            Offset.zero & overlay.size,
          )
        : const RelativeRect.fromLTRB(100, 80, 16, 0);

    final action = await showMenu<String>(
      context: context,
      position: position,
      items: [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile?.displayName?.trim().isNotEmpty == true
                    ? profile!.displayName!.trim()
                    : (profile?.email ?? 'Signed in'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (profile?.email != null)
                Text(
                  profile!.email!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'preferences',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.tune),
            title: Text('Preferences'),
          ),
        ),
        const PopupMenuItem(
          value: 'signout',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout),
            title: Text('Sign out'),
          ),
        ),
      ],
    );

    if (!context.mounted) return;
    switch (action) {
      case 'preferences':
        context.push('/preferences');
      case 'signout':
        await ref.read(authRepositoryProvider).signOut();
      default:
        break;
    }
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile});

  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    final url = profile?.avatarUrl;
    final label = (profile?.greetingName.isNotEmpty == true)
        ? profile!.greetingName[0].toUpperCase()
        : '?';

    return CircleAvatar(
      radius: 16,
      backgroundColor: AppColors.mossSoft,
      foregroundColor: AppColors.mossDeep,
      backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
      child: url == null || url.isEmpty
          ? Text(label, style: const TextStyle(fontWeight: FontWeight.w600))
          : null,
    );
  }
}
