import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../../features/homes/presentation/homes_providers.dart';

Future<void> showHomeInviteSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String homeId,
}) async {
  HomeRole role = HomeRole.viewer;
  var busy = false;
  String? token;
  String? shortCode;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
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
                  'Creates a single-use invite. New members are read-only by default.',
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
                  SelectableText(
                    'Short code: $shortCode',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(token!),
                  const SizedBox(height: 12),
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
                ],
              ],
            ),
          );
        },
      );
    },
  );
}
