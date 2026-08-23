import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../../features/homes/presentation/homes_providers.dart';
import '../../core/layout/web_layout.dart';

/// Builds a join URL for the current deployment (GitHub Pages / app path).
String buildInviteJoinUrl(String shortCodeOrToken) {
  final base = Uri.base;
  final appBase = _webAppBasePath(base.path);
  return Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: '${appBase}homes/join',
    queryParameters: {'code': shortCodeOrToken},
  ).toString();
}

String _webAppBasePath(String path) {
  // Project Pages: /Homeventory/...
  if (path == '/Homeventory' || path.startsWith('/Homeventory/')) {
    return '/Homeventory/';
  }
  const appRoots = {'homes', 'sign-in', 'preferences', 'setup'};
  final parts = path.split('/').where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty || appRoots.contains(parts.first)) return '/';
  return '/${parts.first}/';
}

Future<void> showHomeInviteSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String homeId,
}) async {
  HomeRole role = HomeRole.viewer;
  var busy = false;
  String? token;
  String? shortCode;

  final desktop = isWebDesktopLayout(context);

  Widget buildBody(BuildContext context, void Function(void Function()) setModalState) {
    final joinUrl = shortCode != null || token != null
        ? buildInviteJoinUrl(shortCode ?? token!)
        : null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: desktop ? 8 : 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Invite someone',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Creates a single-use invite. Share the link or short code. '
            'They sign in with Google, then join this home.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<HomeRole>(
            // ignore: deprecated_member_use
            value: role,
            items: HomeRole.values
                .where((r) => r != HomeRole.owner)
                .map(
                  (r) => DropdownMenuItem(value: r, child: Text(r.label)),
                )
                .toList(),
            onChanged: token != null
                ? null
                : (v) {
                    if (v != null) setModalState(() => role = v);
                  },
            decoration: const InputDecoration(labelText: 'Role'),
          ),
          const SizedBox(height: 16),
          if (token == null)
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setModalState(() => busy = true);
                      try {
                        final invite = await ref
                            .read(homesRepositoryProvider)
                            .createInvitation(
                              homeId: homeId,
                              role: role,
                            );
                        setModalState(() {
                          token = invite.token;
                          shortCode = invite.shortCode;
                        });
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                      } finally {
                        setModalState(() => busy = false);
                      }
                    },
              child: Text(busy ? 'Creating…' : 'Create invite'),
            )
          else ...[
            if (joinUrl != null) ...[
              Text('Invite link', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              SelectableText(joinUrl),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: joinUrl));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite link copied')),
                    );
                  }
                },
                icon: const Icon(Icons.link),
                label: const Text('Copy invite link'),
              ),
              const SizedBox(height: 14),
            ],
            SelectableText(
              'Short code: $shortCode',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final value = shortCode ?? token!;
                await Clipboard.setData(ClipboardData(text: value));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        shortCode != null
                            ? 'Short code copied'
                            : 'Invite token copied',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: Text(
                shortCode != null ? 'Copy short code' : 'Copy token',
              ),
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 8),
              Text(
                'Recipients open the link, sign in with Google, and join automatically.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ],
      ),
    );
  }

  if (desktop) {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: buildBody(context, setModalState),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) =>
            buildBody(context, setModalState),
      );
    },
  );
}
