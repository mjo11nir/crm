import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../ui/components/components.dart';

/// Create or edit an appointment. Available times come from the server availability engine.
class AppointmentFormScreen extends ConsumerStatefulWidget {
  const AppointmentFormScreen({super.key, this.initialDate, this.initialStart, this.clientId, this.editId});
  final String? initialDate, initialStart, clientId, editId;
  @override
  ConsumerState<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends ConsumerState<AppointmentFormScreen> {
  late DateTime _date = widget.initialDate != null ? DateTime.parse(widget.initialDate!) : ref.read(selectedDateProvider);
  DateTime? _start; // UTC
  final Set<String> _serviceIds = {};
  Client? _client;
  int _discount = 0;
  int? _duration;
  bool _outsideHours = false;
  int _repeatWeeks = 0; // 0 = no repeat
  int _repeatCount = 4;
  final _notes = TextEditingController();
  bool _saving = false;
  Appointment? _editing;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialStart != null) _start = DateTime.parse(widget.initialStart!).toUtc();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(repositoryProvider);
    final b = ref.read(sessionProvider).value!.businessId;
    try {
      if (widget.editId != null) {
        final a = await repo.appointment(b, widget.editId!);
        _editing = a;
        _start = a.startsAt;
        _date = dateOnly(toBusinessLocal(a.startsAt));
        _serviceIds.addAll(a.serviceIds);
        _duration = a.durationMinutes;
        _notes.text = a.notes ?? '';
        if (a.clientId != null) _client = Client(id: a.clientId!, fullName: a.clientName ?? '', phone: a.clientPhone);
      } else if (widget.clientId != null) {
        _client = (await repo.clientProfile(b, widget.clientId!)).client;
        _discount = _client!.discountPercent;
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (_serviceIds.isEmpty || _start == null) {
      showError(context, l.selectServices);
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(repositoryProvider);
    final b = ref.read(sessionProvider).value!.businessId;
    try {
      if (_editing != null) {
        await repo.updateAppointment(b, _editing!.id, {
          'version': _editing!.version,
          'startsAt': _start!.toIso8601String(),
          'serviceIds': _serviceIds.toList(),
          if (_duration != null) 'durationMinutes': _duration,
          'clientId': _client?.id,
          'notes': _notes.text,
          if (_discount > 0) 'discountPercent': _discount,
          'allowOutsideHours': _outsideHours,
        });
      } else {
        final r = await repo.api.post<Map<String, dynamic>>(
          '/businesses/$b/appointments',
          data: {
            'serviceIds': _serviceIds.toList(),
            'startsAt': _start!.toIso8601String(),
            if (_client != null) 'clientId': _client!.id,
            if (_duration != null) 'durationMinutes': _duration,
            if (_discount > 0) 'discountPercent': _discount,
            if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
            if (_outsideHours) 'allowOutsideHours': true,
            if (_repeatWeeks > 0) 'recurrence': {'everyWeeks': _repeatWeeks, 'count': _repeatCount},
          },
        );
        final conflicts = (r['conflicts'] as List?)?.length ?? 0;
        if (conflicts > 0 && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.conflictsSkipped(conflicts))));
      }
      invalidateCalendar(ref);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) showError(context, e);
      ref.invalidate(_slotsProvider);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final locale = Localizations.localeOf(context).toString();
    final services = ref.watch(servicesProvider);
    final currency = ref.watch(sessionProvider).value?.membership.currency ?? 'EUR';
    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => context.pop(),
          child: Text(l.cancel, style: TextStyle(color: c.primary)),
        ),
        leadingWidth: 96,
        title: Text(_editing != null ? l.reschedule : l.createAppointment),
      ),
      body: !_loaded
          ? const LoadingSkeleton()
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                SettingsGroup(
                  children: [
                    SettingRow(
                      title: l.client,
                      value: _client?.fullName ?? l.noClient,
                      onTap: () async {
                        final picked = await showModalBottomSheet<Client?>(context: context, isScrollControlled: true, builder: (_) => const _ClientPicker());
                        if (picked != null) {
                          setState(() {
                            _client = picked;
                            _discount = picked.discountPercent;
                          });
                        }
                      },
                    ),
                  ],
                ),
                SettingsGroup(
                  header: l.services.toUpperCase(),
                  children: [
                    services.when(
                      data: (list) {
                        final active = list.where((s) => s.isActive || _serviceIds.contains(s.id)).toList();
                        if (active.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: TextButton(onPressed: () => context.push('/service-form'), child: Text(l.newService)),
                          );
                        }
                        return Column(
                          children: [
                            for (final s in active)
                              CheckboxListTile(
                                value: _serviceIds.contains(s.id),
                                activeColor: c.primary,
                                title: Text(s.name),
                                subtitle: Text('${l.minutesShort(s.durationMinutes)} · ${formatMoney(s.priceMinor, currency, locale)}'),
                                onChanged: (v) => setState(() {
                                  v! ? _serviceIds.add(s.id) : _serviceIds.remove(s.id);
                                  if (_editing == null) _start = widget.initialStart != null ? DateTime.parse(widget.initialStart!).toUtc() : null;
                                  _duration = null;
                                }),
                              ),
                          ],
                        );
                      },
                      loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
                      error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(servicesProvider)),
                    ),
                  ],
                ),
                SettingsGroup(
                  header: '${l.date.toUpperCase()} / ${l.time.toUpperCase()}',
                  children: [
                    SettingRow(
                      title: l.date,
                      value: DateFormat('EE, d MMM y', locale).format(_date),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 730)),
                        );
                        if (d != null) {
                          setState(() {
                            _date = d;
                            _start = null;
                          });
                        }
                      },
                    ),
                    if (_serviceIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: _SlotPicker(date: _date, serviceIds: _serviceIds.toList(), selected: _start, onSelect: (s) => setState(() => _start = s)),
                      ),
                    SettingRow(
                      title: l.time,
                      value: _start == null ? '—' : hhmm(_start!),
                      onTap: () async {
                        final init = _start == null ? const TimeOfDay(hour: 9, minute: 0) : TimeOfDay.fromDateTime(toBusinessLocal(_start!));
                        final t = await showTimePicker(context: context, initialTime: init);
                        if (t != null) setState(() => _start = fromBusinessLocal(DateTime(_date.year, _date.month, _date.day, t.hour, t.minute)));
                      },
                    ),
                    SwitchListTile(
                      value: _outsideHours,
                      activeThumbColor: c.primary,
                      title: Text(l.outsideWorkingHours),
                      onChanged: (v) => setState(() => _outsideHours = v),
                    ),
                  ],
                ),
                SettingsGroup(
                  children: [
                    ListTile(
                      title: Text(l.duration),
                      trailing: DropdownButton<int?>(
                        value: _duration,
                        underline: const SizedBox(),
                        items: [
                          DropdownMenuItem(value: null, child: Text(l.auto)),
                          for (final m in [15, 30, 45, 60, 75, 90, 105, 120, 150, 180, 240]) DropdownMenuItem(value: m, child: Text(l.minutesShort(m))),
                          if (_duration != null && ![15, 30, 45, 60, 75, 90, 105, 120, 150, 180, 240].contains(_duration))
                            DropdownMenuItem(value: _duration, child: Text(l.minutesShort(_duration!))),
                        ],
                        onChanged: (v) => setState(() => _duration = v),
                      ),
                    ),
                    ListTile(
                      title: Text(l.discountPercent),
                      trailing: DropdownButton<int>(
                        value: _discount,
                        underline: const SizedBox(),
                        items: [
                          for (final p in {0, 5, 10, 15, 20, 25, 30, 50, 100, _discount}) DropdownMenuItem(value: p, child: Text('$p%')),
                        ],
                        onChanged: (v) => setState(() => _discount = v!),
                      ),
                    ),
                    if (_editing == null)
                      ListTile(
                        title: Text(l.repeat),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButton<int>(
                              value: _repeatWeeks,
                              underline: const SizedBox(),
                              items: [
                                const DropdownMenuItem(value: 0, child: Text('—')),
                                for (final w in [1, 2, 3, 4]) DropdownMenuItem(value: w, child: Text(l.everyNWeeks(w))),
                              ],
                              onChanged: (v) => setState(() => _repeatWeeks = v!),
                            ),
                            if (_repeatWeeks > 0)
                              DropdownButton<int>(
                                value: _repeatCount,
                                underline: const SizedBox(),
                                items: [
                                  for (final n in [2, 3, 4, 6, 8, 12]) DropdownMenuItem(value: n, child: Text('$n')),
                                ],
                                onChanged: (v) => setState(() => _repeatCount = v!),
                              ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _notes,
                        maxLines: 3,
                        decoration: InputDecoration(labelText: l.notes),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: PrimaryButton(label: l.save, loading: _saving, onPressed: _save),
                ),
              ],
            ),
    );
  }
}

final _slotsProvider = FutureProvider.autoDispose.family<List<({DateTime start, String time})>, (String, String)>((ref, k) async {
  final days = await ref.read(repositoryProvider).availability(ref.read(sessionProvider).value!.businessId, from: k.$1, to: k.$1, serviceIds: k.$2.split(','));
  return days.isEmpty ? const [] : days.first.slots;
});

class _SlotPicker extends ConsumerWidget {
  const _SlotPicker({required this.date, required this.serviceIds, required this.selected, required this.onSelect});
  final DateTime date;
  final List<String> serviceIds;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    final v = ref.watch(_slotsProvider((isoDate(date), serviceIds.join(','))));
    return v.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text(errorText(context, e), style: TextStyle(color: c.weekend)),
      data: (slots) => slots.isEmpty
          ? Text(l.noFreeTime, style: TextStyle(color: c.textSecondary))
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in slots)
                  ChoiceChip(
                    label: Text(s.time),
                    selected: selected != null && s.start.isAtSameMomentAs(selected!),
                    selectedColor: c.primary,
                    labelStyle: TextStyle(color: selected != null && s.start.isAtSameMomentAs(selected!) ? Colors.white : c.textPrimary),
                    onSelected: (_) => onSelect(s.start),
                  ),
              ],
            ),
    );
  }
}

class _ClientPicker extends ConsumerStatefulWidget {
  const _ClientPicker();
  @override
  ConsumerState<_ClientPicker> createState() => _ClientPickerState();
}

class _ClientPickerState extends ConsumerState<_ClientPicker> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final v = ref.watch(clientsProvider(_q));
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: l.search, isDense: true),
                    onChanged: (t) => setState(() => _q = t.trim()),
                  ),
                ),
                IconButton(
                  tooltip: l.newClient,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  onPressed: () async {
                    await context.push('/client-form');
                    ref.invalidate(clientsProvider);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncView<({List<Client> items, int total})>(
              value: v,
              data: (r) => r.items.isEmpty
                  ? EmptyState(title: l.nothingHere)
                  : ListView(
                      children: [for (final cl in r.items) ClientCard(client: cl, onTap: () => Navigator.pop(context, cl))],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
