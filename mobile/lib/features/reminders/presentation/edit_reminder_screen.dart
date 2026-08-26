import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/enums.dart';
import '../../../shared/models/inventory_node.dart';
import '../../../shared/models/reminder.dart';
import '../../../shared/utils/reminder_schedule.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../rooms/presentation/rooms_providers.dart';
import '../data/notification_scheduler.dart';
import 'reminders_providers.dart';

class EditReminderScreen extends ConsumerStatefulWidget {
  const EditReminderScreen({
    super.key,
    required this.homeId,
    this.existing,
    this.initialKind,
    this.initialNodeId,
  });

  final String homeId;
  final Reminder? existing;
  final ReminderKind? initialKind;
  final String? initialNodeId;

  @override
  ConsumerState<EditReminderScreen> createState() => _EditReminderScreenState();
}

class _EditReminderScreenState extends ConsumerState<EditReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _interval = TextEditingController(text: '7');
  final _leadDays = TextEditingController(text: '2');
  final _nodeSearch = TextEditingController();

  late ReminderKind _kind;
  ReminderRepeat _repeat = ReminderRepeat.weekly;
  late TimeOfDay _time;
  late DateTime _firstDate;
  InventoryNode? _node;
  String _nodeQuery = '';
  bool _busy = false;
  UsageForecast? _forecast;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _kind = existing?.kind ?? widget.initialKind ?? ReminderKind.manual;
    if (existing != null) {
      _title.text = existing.title;
      _body.text = existing.body ?? '';
      _repeat = existing.repeat;
      _interval.text = '${existing.intervalDays ?? 7}';
      _leadDays.text = '${existing.leadDays}';
      _time = TimeOfDay(
        hour: existing.fireHour,
        minute: existing.fireMinuteOfHour,
      );
      _firstDate = existing.nextFireAt.toLocal();
    } else {
      _time = const TimeOfDay(hour: 9, minute: 0);
      _firstDate = DateTime.now().add(const Duration(days: 1));
      if (_kind == ReminderKind.usageRefill) {
        _repeat = ReminderRepeat.once;
        _title.text = 'Refill reminder';
      } else {
        _title.text = 'Weekly Clean-up';
      }
    }
    final nodeId = existing?.inventoryNodeId ?? widget.initialNodeId;
    if (nodeId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadNode(nodeId));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _interval.dispose();
    _leadDays.dispose();
    _nodeSearch.dispose();
    super.dispose();
  }

  Future<void> _loadNode(String nodeId) async {
    try {
      final node = await ref.read(inventoryRepositoryProvider).getNode(nodeId);
      if (!mounted) return;
      setState(() => _node = node);
      if (_title.text.trim().isEmpty || _title.text == 'Refill reminder') {
        _title.text = 'Refill ${node.name}';
      }
      await _refreshForecast(node);
    } catch (_) {}
  }

  Future<void> _refreshForecast(InventoryNode node) async {
    final txs = await ref
        .read(inventoryRepositoryProvider)
        .listTransactions(node.id);
    if (!mounted) return;
    final lead = int.tryParse(_leadDays.text.trim()) ?? 2;
    setState(() {
      _forecast = forecastRefill(
        transactions: txs,
        quantity: node.quantity,
        leadDays: lead,
        now: DateTime.now(),
      );
    });
  }

  Future<void> _pickTime() async {
    final next = await showTimePicker(context: context, initialTime: _time);
    if (next != null) setState(() => _time = next);
  }

  Future<void> _pickDate() async {
    final next = await showDatePicker(
      context: context,
      initialDate: _firstDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (next != null) setState(() => _firstDate = next);
  }

  DateTime get _computedNextFire {
    final fireMinute = minutesFromMidnight(
      hour: _time.hour,
      minute: _time.minute,
    );
    final interval = int.tryParse(_interval.text.trim());
    if (_kind == ReminderKind.usageRefill && _forecast?.notifyAt != null) {
      return dateAtFireMinute(_forecast!.notifyAt!, fireMinute);
    }
    final first = dateAtFireMinute(_firstDate, fireMinute);
    return nextFireAt(
      from: DateTime.now(),
      repeat: _repeat,
      fireMinute: fireMinute,
      intervalDays: interval,
      firstAt: first,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_kind == ReminderKind.usageRefill && _node == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a container or item to watch.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final scheduler = ref.read(reminderNotificationSchedulerProvider);
      await scheduler.requestPermission();
      final fireMinute = minutesFromMidnight(
        hour: _time.hour,
        minute: _time.minute,
      );
      final interval = _repeat == ReminderRepeat.customDays
          ? int.tryParse(_interval.text.trim())
          : null;
      final lead = int.tryParse(_leadDays.text.trim()) ?? 2;
      final repo = ref.read(remindersRepositoryProvider);
      if (_editing) {
        await repo.updateReminder(
          reminderId: widget.existing!.id,
          kind: _kind,
          title: _title.text,
          body: _body.text,
          repeat: _kind == ReminderKind.usageRefill
              ? ReminderRepeat.once
              : _repeat,
          intervalDays: interval,
          fireMinute: fireMinute,
          nextFireAt: _computedNextFire,
          inventoryNodeId: _node?.id,
          leadDays: lead,
          enabled: true,
        );
      } else {
        await repo.createReminder(
          homeId: widget.homeId,
          kind: _kind,
          title: _title.text,
          body: _body.text,
          repeat: _kind == ReminderKind.usageRefill
              ? ReminderRepeat.once
              : _repeat,
          intervalDays: interval,
          fireMinute: fireMinute,
          nextFireAt: _computedNextFire,
          inventoryNodeId: _node?.id,
          leadDays: lead,
        );
      }
      final list = await repo.listReminders(widget.homeId);
      await scheduler.sync(
        list
            .where((r) => r.enabled)
            .map(ScheduledReminderAlert.fromReminder)
            .toList(),
      );
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this reminder?'),
        content: Text(existing.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(remindersRepositoryProvider).deleteReminder(existing.id);
    await ref.read(reminderNotificationSchedulerProvider).cancel(existing.id);
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final search = _nodeQuery.trim().isEmpty
        ? null
        : ref.watch(
            inventorySearchProvider((homeId: widget.homeId, query: _nodeQuery)),
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit reminder' : 'New reminder'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_editing)
            IconButton(
              tooltip: 'Delete',
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            DropdownButtonFormField<ReminderKind>(
              // ignore: deprecated_member_use
              value: _kind,
              decoration: const InputDecoration(labelText: 'Kind'),
              items: [
                for (final kind in ReminderKind.values)
                  DropdownMenuItem(value: kind, child: Text(kind.label)),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _kind = v;
                  if (v == ReminderKind.usageRefill) {
                    _repeat = ReminderRepeat.once;
                    if (_title.text == 'Weekly Clean-up') {
                      _title.text = 'Refill reminder';
                    }
                  } else if (_title.text == 'Refill reminder') {
                    _title.text = 'Weekly Clean-up';
                    _repeat = ReminderRepeat.weekly;
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Monthly Clean-up',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _body,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'What should the notification say?',
              ),
              maxLines: 2,
            ),
            if (_kind == ReminderKind.manual) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<ReminderRepeat>(
                // ignore: deprecated_member_use
                value: _repeat,
                decoration: const InputDecoration(labelText: 'Repeat'),
                items: [
                  for (final repeat in ReminderRepeat.values)
                    DropdownMenuItem(value: repeat, child: Text(repeat.label)),
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
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    if (n == null || n < 1) return 'Enter 1 or more days';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('First date'),
                subtitle: Text(DateFormat.yMMMd().format(_firstDate)),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _pickDate,
              ),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Time'),
              subtitle: Text(_time.format(context)),
              trailing: const Icon(Icons.schedule),
              onTap: _pickTime,
            ),
            if (_kind == ReminderKind.usageRefill) ...[
              const SizedBox(height: 8),
              const SectionLabel('Container or item'),
              const SizedBox(height: 8),
              if (_node != null)
                SoftTile(
                  title: _node!.name,
                  subtitle: [
                    _node!.kindLabel,
                    if (_node!.quantity != null)
                      '${_node!.quantity} ${_node!.quantityUnit ?? ''}'.trim(),
                  ].join(' · '),
                  trailing: IconButton(
                    tooltip: 'Clear',
                    onPressed: () => setState(() {
                      _node = null;
                      _forecast = null;
                    }),
                    icon: const Icon(Icons.close),
                  ),
                )
              else ...[
                TextField(
                  controller: _nodeSearch,
                  decoration: const InputDecoration(
                    hintText: 'Search by name…',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _nodeQuery = v),
                ),
                const SizedBox(height: 8),
                if (search != null)
                  search.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Text(e.toString()),
                    data: (nodes) {
                      if (nodes.isEmpty) {
                        return const Text('No matches.');
                      }
                      return Column(
                        children: [
                          for (final node in nodes.take(8))
                            SoftTile(
                              title: node.name,
                              subtitle: node.kindLabel,
                              onTap: () async {
                                setState(() {
                                  _node = node;
                                  _nodeQuery = '';
                                  _nodeSearch.clear();
                                  if (_title.text.trim().isEmpty ||
                                      _title.text == 'Refill reminder') {
                                    _title.text = 'Refill ${node.name}';
                                  }
                                });
                                await _refreshForecast(node);
                              },
                            ),
                        ],
                      );
                    },
                  ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _leadDays,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Notify how many days before empty?',
                ),
                onChanged: (_) {
                  final node = _node;
                  if (node != null) _refreshForecast(node);
                },
              ),
              if (_forecast != null) ...[
                const SizedBox(height: 12),
                Text(
                  '${_forecast!.confidenceLabel}. ${_forecast!.explanation}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving…' : 'Save reminder'),
            ),
          ],
        ),
      ),
    );
  }
}
