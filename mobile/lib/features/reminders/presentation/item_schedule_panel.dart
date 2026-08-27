import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/enums.dart';
import '../../../shared/models/inventory_node.dart';
import '../../../shared/models/reminder.dart';
import '../../../shared/utils/reminder_schedule.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../rooms/presentation/rooms_providers.dart';
import '../data/reminder_image_urls.dart';
import 'reminders_providers.dart';

/// Notification schedule block used on item create/edit and the Schedule tab.
class ItemSchedulePanel extends ConsumerStatefulWidget {
  const ItemSchedulePanel({
    super.key,
    required this.homeId,
    this.nodeId,
    this.itemName,
  });

  final String homeId;
  final String? nodeId;
  final String? itemName;

  @override
  ConsumerState<ItemSchedulePanel> createState() => ItemSchedulePanelState();
}

class ItemSchedulePanelState extends ConsumerState<ItemSchedulePanel> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _interval = TextEditingController(text: '7');
  final _leadDays = TextEditingController(text: '2');

  bool _enabled = false;
  ReminderKind _kind = ReminderKind.manual;
  ReminderRepeat _repeat = ReminderRepeat.weekly;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  DateTime _firstDate = DateTime.now().add(const Duration(days: 1));
  Reminder? _existing;
  List<Reminder> _others = const [];
  UsageForecast? _forecast;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _title.text = widget.itemName?.trim().isNotEmpty == true
        ? widget.itemName!.trim()
        : 'Weekly Clean-up';
    if (widget.nodeId != null) {
      _loadExisting();
    } else {
      _loaded = true;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _interval.dispose();
    _leadDays.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final all = await ref
          .read(remindersRepositoryProvider)
          .listForNode(homeId: widget.homeId, nodeId: widget.nodeId!);
      if (!mounted) return;
      final primary = all.isEmpty ? null : all.first;
      setState(() {
        _others = all.skip(1).toList();
        _existing = primary;
        _enabled = primary != null && primary.enabled;
        if (primary != null) {
          _kind = primary.kind;
          _title.text = primary.title;
          _body.text = primary.body ?? '';
          _repeat = primary.repeat;
          _interval.text = '${primary.intervalDays ?? 7}';
          _leadDays.text = '${primary.leadDays}';
          _time = TimeOfDay(
            hour: primary.fireHour,
            minute: primary.fireMinuteOfHour,
          );
          _firstDate = primary.nextFireAt.toLocal();
        }
        _loaded = true;
      });
      if (primary?.kind == ReminderKind.usageRefill && widget.nodeId != null) {
        await _refreshForecast(widget.nodeId!);
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _refreshForecast(String nodeId) async {
    try {
      final node = await ref.read(inventoryRepositoryProvider).getNode(nodeId);
      final txs = await ref
          .read(inventoryRepositoryProvider)
          .listTransactions(nodeId);
      if (!mounted) return;
      setState(() {
        _forecast = forecastRefill(
          transactions: txs,
          quantity: node.quantity,
          leadDays: int.tryParse(_leadDays.text.trim()) ?? 2,
          now: DateTime.now(),
        );
      });
    } catch (_) {}
  }

  DateTime _nextFire({InventoryNode? node}) {
    final fireMinute = minutesFromMidnight(
      hour: _time.hour,
      minute: _time.minute,
    );
    if (_kind == ReminderKind.usageRefill && _forecast?.notifyAt != null) {
      return dateAtFireMinute(_forecast!.notifyAt!, fireMinute);
    }
    return nextFireAt(
      from: DateTime.now(),
      repeat: _repeat,
      fireMinute: fireMinute,
      intervalDays: int.tryParse(_interval.text.trim()),
      firstAt: dateAtFireMinute(_firstDate, fireMinute),
    );
  }

  String? validate() {
    if (!_enabled) return null;
    if (_title.text.trim().isEmpty) return 'Enter a schedule title';
    if (_repeat == ReminderRepeat.customDays) {
      final n = int.tryParse(_interval.text.trim());
      if (n == null || n < 1) {
        return 'Enter how many days between notifications';
      }
    }
    return null;
  }

  /// Creates, updates, or turns off the schedule for [node].
  Future<void> saveForNode(InventoryNode node) async {
    final repo = ref.read(remindersRepositoryProvider);
    final scheduler = ref.read(reminderNotificationSchedulerProvider);
    if (!_enabled) {
      if (_existing != null) {
        await repo.updateReminder(reminderId: _existing!.id, enabled: false);
        await scheduler.cancel(_existing!.id);
      }
      return;
    }
    await scheduler.requestPermission();
    final fireMinute = minutesFromMidnight(
      hour: _time.hour,
      minute: _time.minute,
    );
    final interval = _repeat == ReminderRepeat.customDays
        ? int.tryParse(_interval.text.trim())
        : null;
    final lead = int.tryParse(_leadDays.text.trim()) ?? 2;
    final title = _title.text.trim().isEmpty ? node.name : _title.text.trim();
    final repeat = _kind == ReminderKind.usageRefill
        ? ReminderRepeat.once
        : _repeat;
    if (_existing != null) {
      await repo.updateReminder(
        reminderId: _existing!.id,
        kind: _kind,
        title: title,
        body: _body.text,
        repeat: repeat,
        intervalDays: interval,
        fireMinute: fireMinute,
        nextFireAt: _nextFire(node: node),
        inventoryNodeId: node.id,
        leadDays: lead,
        enabled: true,
      );
    } else {
      await repo.createReminder(
        homeId: widget.homeId,
        kind: _kind,
        title: title,
        body: _body.text,
        repeat: repeat,
        intervalDays: interval,
        fireMinute: fireMinute,
        nextFireAt: _nextFire(node: node),
        inventoryNodeId: node.id,
        leadDays: lead,
      );
    }
    final list = await repo.listReminders(widget.homeId);
    await scheduler.sync(
      await scheduledAlertsWithImages(
        reminders: list,
        latestImageUrls: ref.read(inventoryRepositoryProvider).latestImageUrls,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final dateFormat = DateFormat.yMMMd();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Notification schedule'),
        const SizedBox(height: 8),
        Text(
          'Android can notify at this time. The Schedule tab lists every alarm in the home.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Notify me'),
          subtitle: Text(
            _kind == ReminderKind.usageRefill
                ? 'When this is likely to run out'
                : 'On a repeating or one-time alarm',
          ),
          value: _enabled,
          onChanged: (v) => setState(() => _enabled = v),
        ),
        if (_others.isNotEmpty) ...[
          for (final other in _others)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SoftTile(
                title: other.title,
                subtitle: '${other.kind.label} · ${other.repeatSummary}',
              ),
            ),
        ],
        if (_enabled) ...[
          DropdownButtonFormField<ReminderKind>(
            // ignore: deprecated_member_use
            value: _kind,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Schedule type'),
            items: [
              DropdownMenuItem(
                value: ReminderKind.manual,
                child: const Text(
                  'Alarm (your text and repeat)',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: ReminderKind.usageRefill,
                child: const Text(
                  'Refill from usage',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _kind = v;
                if (v == ReminderKind.usageRefill) {
                  _repeat = ReminderRepeat.once;
                  if (_title.text == 'Weekly Clean-up' &&
                      widget.itemName != null) {
                    _title.text = 'Refill ${widget.itemName}';
                  }
                  if (widget.nodeId != null) _refreshForecast(widget.nodeId!);
                }
              });
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notification title',
              hintText: 'Monthly Clean-up',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _body,
            decoration: const InputDecoration(
              labelText: 'Notification text (optional)',
            ),
            maxLines: 2,
          ),
          if (_kind == ReminderKind.manual) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<ReminderRepeat>(
              // ignore: deprecated_member_use
              value: _repeat,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Repeat'),
              items: [
                for (final repeat in ReminderRepeat.values)
                  DropdownMenuItem(
                    value: repeat,
                    child: Text(repeat.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _repeat = v);
              },
            ),
            if (_repeat == ReminderRepeat.customDays) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _interval,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Every how many days?',
                ),
              ),
            ],
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('First date'),
              subtitle: Text(dateFormat.format(_firstDate)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final next = await showDatePicker(
                  context: context,
                  initialDate: _firstDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                );
                if (next != null) setState(() => _firstDate = next);
              },
            ),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Time'),
            subtitle: Text(_time.format(context)),
            trailing: const Icon(Icons.schedule),
            onTap: () async {
              final next = await showTimePicker(
                context: context,
                initialTime: _time,
              );
              if (next != null) setState(() => _time = next);
            },
          ),
          if (_kind == ReminderKind.usageRefill) ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: _leadDays,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Days before empty to notify',
              ),
              onChanged: (_) {
                if (widget.nodeId != null) _refreshForecast(widget.nodeId!);
              },
            ),
            if (_forecast != null) ...[
              const SizedBox(height: 8),
              Text(
                '${_forecast!.confidenceLabel}. ${_forecast!.explanation}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ],
      ],
    );
  }
}
