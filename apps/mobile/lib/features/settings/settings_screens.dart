import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../ui/components/components.dart';

String _bid(WidgetRef ref) => ref.read(sessionProvider).value!.businessId;
String _hm(int m) => '${(m ~/ 60 % 24).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

Future<int?> _pickMinute(BuildContext context, int initial) async {
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: initial ~/ 60 % 24, minute: initial % 60),
  );
  return t == null ? null : t.hour * 60 + t.minute;
}

// ---------------------------------------------------------------- work schedule
final _employeesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ref.read(repositoryProvider).employees(bizId(ref)));

class WorkScheduleScreen extends ConsumerStatefulWidget {
  const WorkScheduleScreen({super.key});
  @override
  ConsumerState<WorkScheduleScreen> createState() => _WorkScheduleScreenState();
}

class _WorkScheduleScreenState extends ConsumerState<WorkScheduleScreen> {
  Map<int, ScheduleDay>? _days;
  String? _employeeId;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final locale = Localizations.localeOf(context).toString();
    final emps = ref.watch(_employeesProvider);
    final biz = ref.watch(businessProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.scheduleAndPlace)),
      body: AsyncView<List<Map<String, dynamic>>>(
        value: emps,
        onRetry: () => ref.invalidate(_employeesProvider),
        data: (list) {
          final locations = biz.value?.locations ?? const <Location>[];
          if (list.isEmpty || locations.isEmpty) return const LoadingSkeleton();
          _employeeId ??= list.first['id'] as String;
          _days ??= {for (final s in (list.first['schedules'] as List)) (s['weekday'] as num).toInt(): ScheduleDay.fromJson(s)};
          final weekdays = List.generate(7, (i) => DateFormat('EEEE', locale).format(DateTime(2024, 1, 1 + i)));
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              SettingsGroup(
                header: l.workingHours.toUpperCase(),
                indentDividers: 16,
                children: [
                  for (var wd = 1; wd <= 7; wd++)
                    Builder(
                      builder: (_) {
                        final d = _days![wd];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      toBeginningOfSentenceCase(weekdays[wd - 1]),
                                      style: TextStyle(fontSize: 17, color: d == null ? c.weekend : c.textPrimary),
                                    ),
                                  ),
                                  Switch(
                                    value: d != null,
                                    activeThumbColor: c.primary,
                                    onChanged: (on) => setState(
                                      () => on
                                          ? _days![wd] = ScheduleDay(weekday: wd, startMinute: 540, endMinute: 1140, locationId: locations.first.id)
                                          : _days!.remove(wd),
                                    ),
                                  ),
                                ],
                              ),
                              if (d != null)
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () async => _set(d, start: await _pickMinute(context, d.startMinute)),
                                      child: Text(_hm(d.startMinute)),
                                    ),
                                    const Text('—'),
                                    TextButton(
                                      onPressed: () async => _set(d, end: await _pickMinute(context, d.endMinute % 1440)),
                                      child: Text(_hm(d.endMinute)),
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () async {
                                        if (d.breakStartMinute != null) {
                                          setState(
                                            () => d
                                              ..breakStartMinute = null
                                              ..breakEndMinute = null,
                                          );
                                          return;
                                        }
                                        final s = await _pickMinute(context, 780);
                                        if (s == null || !context.mounted) return;
                                        final e = await _pickMinute(context, s + 60);
                                        if (e != null) {
                                          setState(
                                            () => d
                                              ..breakStartMinute = s
                                              ..breakEndMinute = e,
                                          );
                                        }
                                      },
                                      child: Text(
                                        d.breakStartMinute == null
                                            ? '+ ${l.breakLabel}'
                                            : '${l.breakLabel} ${_hm(d.breakStartMinute!)}–${_hm(d.breakEndMinute!)}  ×',
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
              SettingsGroup(
                header: l.locations.toUpperCase(),
                indentDividers: 16,
                children: [
                  for (final loc in locations) SettingRow(title: loc.name, subtitle: loc.address),
                  SettingRow(
                    title: l.addLocation,
                    icon: Icons.add_location_alt_rounded,
                    iconColor: c.primary,
                    onTap: () async {
                      final name = TextEditingController(), addr = TextEditingController();
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(l.addLocation),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: name,
                                decoration: InputDecoration(labelText: l.name),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: addr,
                                decoration: InputDecoration(labelText: l.address),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.save)),
                          ],
                        ),
                      );
                      if (ok == true && name.text.trim().isNotEmpty) {
                        try {
                          await ref.read(repositoryProvider).createLocation(_bid(ref), name.text.trim(), addr.text.trim());
                          ref.invalidate(businessProvider);
                        } catch (e) {
                          if (context.mounted) showError(context, e);
                        }
                      }
                    },
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: PrimaryButton(
                  label: l.save,
                  loading: _busy,
                  onPressed: () async {
                    setState(() => _busy = true);
                    try {
                      await ref.read(repositoryProvider).replaceSchedule(_bid(ref), _employeeId!, _days!.values.toList());
                      ref.invalidate(_employeesProvider);
                      ref.invalidate(workdaysProvider);
                      invalidateCalendar(ref);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.save)));
                    } catch (e) {
                      if (context.mounted) showError(context, e);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _set(ScheduleDay d, {int? start, int? end}) {
    setState(() {
      if (start != null) d.startMinute = start;
      if (end != null) d.endMinute = end <= d.startMinute ? end + 1440 : end; // overnight shift
    });
  }
}

// ---------------------------------------------------------------- online booking
class OnlineBookingSettingsScreen extends ConsumerWidget {
  const OnlineBookingSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final v = ref.watch(businessProvider);
    Future<void> patch(Map<String, dynamic> body) async {
      try {
        await ref.read(repositoryProvider).updateBusiness(_bid(ref), body);
        ref.invalidate(businessProvider);
      } catch (e) {
        if (context.mounted) showError(context, e);
      }
    }

    Widget numberRow(String title, int value, List<int> options, String field) => ListTile(
      title: Text(title),
      trailing: DropdownButton<int>(
        value: value,
        underline: const SizedBox(),
        items: [
          for (final o in {...options, value}) DropdownMenuItem(value: o, child: Text('$o')),
        ],
        onChanged: (x) => patch({field: x}),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.onlineBooking)),
      body: AsyncView<Business>(
        value: v,
        onRetry: () => ref.invalidate(businessProvider),
        data: (b) {
          final url = '${apiBaseUrl.replaceAll(RegExp(r':\d+/api/v1$'), ':3001').replaceAll('/api/v1', '')}/${b.slug}';
          return ListView(
            children: [
              SettingsGroup(
                indentDividers: 16,
                children: [
                  SwitchListTile(
                    value: b.onlineBookingEnabled,
                    activeThumbColor: c.primary,
                    title: Text(l.onlineBooking),
                    onChanged: (x) => patch({'onlineBookingEnabled': x}),
                  ),
                  SettingRow(
                    title: l.bookingLink,
                    subtitle: url,
                    trailing: const Icon(Icons.copy_rounded),
                    showChevron: false,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: url));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.copied)));
                    },
                  ),
                ],
              ),
              SettingsGroup(
                indentDividers: 16,
                children: [
                  numberRow(l.minNotice, b.minNoticeMinutes, [0, 30, 60, 120, 240, 720, 1440], 'minNoticeMinutes'),
                  numberRow(l.maxHorizon, b.maxHorizonDays, [7, 14, 30, 60, 90, 180], 'maxHorizonDays'),
                  numberRow(l.slotStep, b.slotStepMinutes, [10, 15, 20, 30, 60], 'slotStepMinutes'),
                  SwitchListTile(
                    value: b.requireApproval,
                    activeThumbColor: c.primary,
                    title: Text(l.requireApproval),
                    onChanged: (x) => patch({'requireApproval': x}),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- waitlist
final _waitlistProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ref.read(repositoryProvider).waitlist(bizId(ref)));

class WaitlistScreen extends ConsumerWidget {
  const WaitlistScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final b = ref.watch(businessProvider).value;
    final v = ref.watch(_waitlistProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.waitlist)),
      body: ListView(
        children: [
          if (b != null)
            SettingsGroup(
              children: [
                SwitchListTile(
                  value: b.waitlistEnabled,
                  activeThumbColor: c.primary,
                  title: Text(l.waitlist),
                  onChanged: (x) async {
                    await ref.read(repositoryProvider).updateBusiness(_bid(ref), {'waitlistEnabled': x});
                    ref.invalidate(businessProvider);
                  },
                ),
              ],
            ),
          v.when(
            loading: () => const LoadingSkeleton(rows: 2),
            error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(_waitlistProvider)),
            data: (list) => list.isEmpty
                ? EmptyState(title: l.nothingHere)
                : SettingsGroup(
                    indentDividers: 16,
                    children: [
                      for (final w in list)
                        SettingRow(
                          title: w['client']['fullName'],
                          subtitle:
                              '${w['service']['name']} · ${(w['preferredFrom'] as String).substring(0, 10)} – ${(w['preferredTo'] as String).substring(0, 10)}',
                          value: w['status'],
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- web page
class WebPageScreen extends ConsumerWidget {
  const WebPageScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final v = ref.watch(businessProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.webPage)),
      body: AsyncView<Business>(
        value: v,
        data: (b) {
          final desc = TextEditingController(text: b.raw['description'] ?? '');
          final name = TextEditingController(text: b.name);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: name,
                decoration: InputDecoration(labelText: l.businessName),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: desc,
                maxLines: 4,
                decoration: InputDecoration(labelText: l.notes),
              ),
              const SizedBox(height: 12),
              Text('${l.bookingLink}: /${b.slug}', style: TextStyle(color: context.colors.textSecondary)),
              const SizedBox(height: 16),
              PrimaryButton(
                label: l.save,
                onPressed: () async {
                  try {
                    await ref.read(repositoryProvider).updateBusiness(_bid(ref), {'name': name.text.trim(), 'description': desc.text.trim()});
                    ref.invalidate(businessProvider);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.save)));
                  } catch (e) {
                    if (context.mounted) showError(context, e);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- notifications
final _jobsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ref.read(repositoryProvider).notifications(bizId(ref)));

class ClientNotificationsScreen extends ConsumerWidget {
  const ClientNotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final locale = Localizations.localeOf(context).toString();
    final v = ref.watch(_jobsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.clientNotifications)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_jobsProvider),
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(l.sandboxDelivery, style: TextStyle(color: c.textSecondary)),
            ),
            v.when(
              loading: () => const LoadingSkeleton(),
              error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(_jobsProvider)),
              data: (jobs) => jobs.isEmpty
                  ? EmptyState(title: l.nothingHere, icon: Icons.notifications_none_rounded)
                  : SettingsGroup(
                      indentDividers: 16,
                      children: [
                        for (final j in jobs)
                          SettingRow(
                            title: '${j['template']} · ${j['channel']}',
                            subtitle: '${j['recipient']} · ${DateFormat('d MMM HH:mm', locale).format(toBusinessLocal(DateTime.parse(j['scheduledFor'])))}',
                            value: j['status'],
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockedScreen extends StatelessWidget {
  const _BlockedScreen({required this.title, required this.body, required this.icon});
  final String title, body;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: EmptyState(title: body, icon: icon),
  );
}

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _BlockedScreen(title: l.alerts, body: 'Push (FCM/APNs): ${l.notConnected}', icon: Icons.notifications_off_outlined);
  }
}

class CalendarSyncScreen extends StatelessWidget {
  const CalendarSyncScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _BlockedScreen(title: l.calendarSync, body: 'Google / Apple Calendar: ${l.notConnected}', icon: Icons.event_busy_outlined);
  }
}

// ---------------------------------------------------------------- appearance & language
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final mode = ref.watch(prefsProvider).themeMode;
    return Scaffold(
      appBar: AppBar(title: Text(l.appearance)),
      body: ListView(
        children: [
          SettingsGroup(
            indentDividers: 16,
            children: [
              for (final (m, label) in [(ThemeMode.system, l.themeSystem), (ThemeMode.light, l.themeLight), (ThemeMode.dark, l.themeDark)])
                SettingRow(
                  title: label,
                  showChevron: false,
                  trailing: mode == m ? Icon(Icons.check_rounded, color: context.colors.primary) : null,
                  onTap: () => ref.read(prefsProvider.notifier).setTheme(m),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final current = ref.watch(prefsProvider).locale;
    const names = {'ru': 'Русский', 'en': 'English', 'tr': 'Türkçe', 'pt': 'Português', 'es': 'Español'};
    return Scaffold(
      appBar: AppBar(title: Text(l.languageRegion)),
      body: ListView(
        children: [
          SettingsGroup(
            header: l.language.toUpperCase(),
            indentDividers: 16,
            children: [
              SettingRow(
                title: l.systemLanguage,
                showChevron: false,
                trailing: current == null ? Icon(Icons.check_rounded, color: context.colors.primary) : null,
                onTap: () => ref.read(prefsProvider.notifier).setLocale(null),
              ),
              for (final e in names.entries)
                SettingRow(
                  title: e.value,
                  showChevron: false,
                  trailing: current?.languageCode == e.key ? Icon(Icons.check_rounded, color: context.colors.primary) : null,
                  onTap: () => ref.read(prefsProvider.notifier).setLocale(Locale(e.key)),
                ),
            ],
          ),
          SettingsGroup(
            indentDividers: 16,
            children: [
              SettingRow(title: l.timezone, value: ref.watch(sessionProvider).value?.membership.timezone),
              SettingRow(title: l.currency, value: ref.watch(sessionProvider).value?.membership.currency),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- subscription
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final v = ref.watch(subscriptionProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.subscription)),
      body: AsyncView<Map<String, dynamic>>(
        value: v,
        onRetry: () => ref.invalidate(subscriptionProvider),
        data: (s) => ListView(
          children: [
            SettingsGroup(
              indentDividers: 16,
              children: [
                SettingRow(title: l.plan, value: '${s['tier'] ?? '—'}'),
                SettingRow(title: l.status, value: s['status'] == 'EXPIRED' ? l.expired : '${s['status']}'),
                if (s['trialDaysLeft'] != null) SettingRow(title: l.trialDaysLeft(s['trialDaysLeft'] as int)),
                if (s['expiresAt'] != null) SettingRow(title: l.expiresAt, value: DateFormat.yMMMd().format(DateTime.parse(s['expiresAt']))),
              ],
            ),
            SettingsGroup(
              header: l.features.toUpperCase(),
              indentDividers: 16,
              children: [
                for (final f in (s['features'] as List))
                  SettingRow(
                    title: '$f',
                    trailing: Icon(Icons.check_circle_rounded, color: c.green),
                    showChevron: false,
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(l.storeBillingBlocked, style: TextStyle(color: c.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- statistics
final _reportProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, DateTime>((ref, month) {
  final from = DateTime(month.year, month.month);
  final to = DateTime(month.year, month.month + 1, 0);
  return ref.read(repositoryProvider).report(bizId(ref), isoDate(from), isoDate(to));
});

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});
  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  DateTime _month = DateTime(businessToday().year, businessToday().month);
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final locale = Localizations.localeOf(context).toString();
    final v = ref.watch(_reportProvider(_month));
    return Scaffold(
      appBar: AppBar(title: Text(l.statistics)),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                icon: Icon(Icons.chevron_left_rounded, color: c.primary),
              ),
              Text(
                toBeginningOfSentenceCase(DateFormat('LLLL yyyy', locale).format(_month)),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.primary),
              ),
              IconButton(
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                icon: Icon(Icons.chevron_right_rounded, color: c.primary),
              ),
            ],
          ),
          Expanded(
            child: AsyncView<Map<String, dynamic>>(
              value: v,
              onRetry: () => ref.invalidate(_reportProvider),
              data: (r) {
                final cur = r['currency'] as String;
                String m(Object? x) => formatMoney((x as num).toInt(), cur, locale);
                final appts = r['appointments'] as Map<String, dynamic>;
                final daily = (r['daily'] as List).cast<Map<String, dynamic>>();
                final maxDay = daily.fold<int>(1, (a, d) => (d['amountMinor'] as int) > a ? d['amountMinor'] as int : a);
                return ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    SettingsGroup(
                      indentDividers: 16,
                      children: [
                        SettingRow(title: l.earned, value: m(r['earnedRevenueMinor'])),
                        SettingRow(title: '${l.deposit} + ${l.payment} − ${l.refund}', value: m(r['cashFlow']['netMinor'])),
                        SettingRow(title: l.expenses, value: m(r['expensesMinor'])),
                        SettingRow(title: l.profit, value: m(r['profitEstimateMinor'])),
                      ],
                    ),
                    if (daily.isNotEmpty)
                      Container(
                        height: 140,
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final d in daily)
                              Expanded(
                                child: Tooltip(
                                  message: '${d['date']}: ${m(d['amountMinor'])}',
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                    height: 110 * (d['amountMinor'] as int) / maxDay,
                                    decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(3)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    SettingsGroup(
                      indentDividers: 16,
                      children: [
                        SettingRow(title: l.appointmentsCount, value: '${appts['total']}'),
                        SettingRow(title: l.statusCOMPLETED, value: '${appts['completed']}'),
                        SettingRow(title: l.statusCANCELLED, value: '${appts['cancelled']}'),
                        SettingRow(title: l.noShowRate, value: '${((appts['noShowRate'] as num) * 100).toStringAsFixed(1)}%'),
                        SettingRow(title: l.averageTicket, value: m(appts['averageTicketMinor'])),
                        SettingRow(title: l.clients, value: '+${r['clients']['new']} / ${r['clients']['returning']}'),
                      ],
                    ),
                    if ((r['byService'] as List).isNotEmpty)
                      SettingsGroup(
                        header: l.topServices.toUpperCase(),
                        indentDividers: 16,
                        children: [for (final s in (r['byService'] as List).take(10)) SettingRow(title: s['name'], value: m(s['amountMinor']))],
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- account
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(sessionProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l.profile)),
      body: ListView(
        children: [
          if (s != null)
            SettingsGroup(
              indentDividers: 16,
              children: [
                SettingRow(title: l.fullName, value: s.me.fullName),
                SettingRow(title: l.email, value: s.me.email),
                SettingRow(title: l.businessName, value: s.membership.businessName),
              ],
            ),
          SettingsGroup(
            indentDividers: 16,
            children: [
              SettingRow(title: l.logoutAll, showChevron: false, onTap: () => ref.read(sessionProvider.notifier).logout(everywhere: true)),
              SettingRow(
                title: l.deleteAccount,
                destructive: true,
                showChevron: false,
                onTap: () async {
                  final pw = TextEditingController();
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l.deleteAccount),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l.deleteAccountWarning),
                          TextField(
                            controller: pw,
                            obscureText: true,
                            decoration: InputDecoration(labelText: l.password),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(l.deleteAccount, style: TextStyle(color: context.colors.weekend)),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  try {
                    await ref.read(repositoryProvider).deleteAccount(pw.text);
                    ref.read(sessionProvider.notifier).expired();
                  } catch (e) {
                    if (context.mounted) showError(context, e);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
