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

enum ScheduleView { day, week, feed }

/// Расписание (reference screenshot 1).
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});
  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  ScheduleView _view = ScheduleView.day;
  bool _collapsed = false;
  DateTime? _month;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final locale = Localizations.localeOf(context).toString();
    final selected = ref.watch(selectedDateProvider);
    final month = _month ?? DateTime(selected.year, selected.month);
    final today = businessToday();
    final workdays = ref.watch(workdaysProvider).value ?? {1, 2, 3, 4, 5};
    final dots = ref.watch(dotsProvider((isoDate(MonthCalendar.gridStart(month)), isoDate(MonthCalendar.gridEnd(month))))).value ?? const {};
    final day = ref.watch(dayProvider(isoDate(selected)));

    void select(DateTime d) {
      ref.read(selectedDateProvider.notifier).set(d);
      setState(() => _month = DateTime(d.year, d.month));
    }

    return Scaffold(
      backgroundColor: c.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              // The calendar header scrolls away with the list so small screens stay usable.
              child: NestedScrollView(
                headerSliverBuilder: (context, _) => [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        Container(
                          color: c.background,
                          child: Column(
                            children: [
                              const SizedBox(height: 10),
                              SegmentedControl<ScheduleView>(
                                segments: {ScheduleView.day: l.day, ScheduleView.week: l.week, ScheduleView.feed: l.feed},
                                value: _view,
                                onChanged: (v) => setState(() => _view = v),
                              ),
                              if (_view != ScheduleView.feed) ...[
                                const SizedBox(height: 14),
                                GestureDetector(
                                  onTap: () => setState(() => _collapsed = !_collapsed),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        toBeginningOfSentenceCase(DateFormat(month.year == today.year ? 'LLLL' : 'LLLL yyyy', locale).format(month)),
                                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: c.primary),
                                      ),
                                      Icon(_collapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded, color: c.primary),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                GestureDetector(
                                  onHorizontalDragEnd: (d) {
                                    final v = d.primaryVelocity ?? 0;
                                    if (v.abs() < 200) return;
                                    setState(() => _month = DateTime(month.year, month.month + (v < 0 ? 1 : -1)));
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: MonthCalendar(
                                      month: month,
                                      selected: selected,
                                      today: today,
                                      workdays: workdays,
                                      dots: dots,
                                      onSelect: select,
                                      locale: locale,
                                      collapsed: _collapsed,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 10, 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          dateOnly(selected) == today
                                              ? l.todayWithDate(toBeginningOfSentenceCase(DateFormat('EE, d MMM', locale).format(selected)))
                                              : toBeginningOfSentenceCase(DateFormat('EE, d MMM', locale).format(selected)),
                                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500, color: c.cyan),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => context.go('/more/work-schedule'),
                                        child: Row(
                                          children: [
                                            Text(
                                              day.value?.workStart == null ? l.dayOff : '${hhmm(day.value!.workStart!)} - ${hhmm(day.value!.workEnd!)}',
                                              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500, color: c.cyan),
                                            ),
                                            Icon(Icons.chevron_right_rounded, color: c.cyan, size: 28),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (_view == ScheduleView.feed)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                                  child: TextField(
                                    decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: l.search, isDense: true),
                                    onSubmitted: (v) => setState(() => _query = v.trim()),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          height: 1,
                          decoration: BoxDecoration(
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 3, offset: const Offset(0, 1))],
                            color: c.divider,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                body: switch (_view) {
                  ScheduleView.day => _DayList(date: selected, locale: locale),
                  ScheduleView.week => _WeekList(weekStart: startOfWeek(selected), locale: locale, workdays: workdays),
                  ScheduleView.feed => _Feed(query: _query, locale: locale),
                },
              ),
            ),
            _BottomBar(
              revenue: day.value == null ? null : formatMoney(day.value!.revenueMinor, day.value!.currency, locale),
              onToday: () => select(today),
              onSearch: () => setState(() => _view = ScheduleView.feed),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayList extends ConsumerWidget {
  const _DayList({required this.date, required this.locale});
  final DateTime date;
  final String locale;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final v = ref.watch(dayProvider(isoDate(date)));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(dayProvider),
      child: AsyncView<DayView>(
        value: v,
        onRetry: () => ref.invalidate(dayProvider),
        data: (d) {
          final now = appNow().toUtc();
          // Free gaps in the past are not actionable; clip to "now" for today.
          final gaps = [
            for (final g in d.gaps)
              if (g.end.isAfter(now)) g.start.isBefore(now) ? FreeGap(_roundUp(now), g.end, g.end.difference(_roundUp(now)).inMinutes) : g,
          ].where((g) => g.minutes >= 15).toList();
          final items = <(DateTime, Widget)>[
            for (final a in d.appointments)
              (a.startsAt, AppointmentCard(appointment: a, currency: d.currency, locale: locale, onTap: () => context.push('/appointment/${a.id}'))),
            for (final g in gaps)
              (g.start, FreeGapCard(gap: g, onTap: () => context.push('/appointment/new?date=${d.date}&start=${g.start.toIso8601String()}'))),
          ]..sort((a, b) => a.$1.compareTo(b.$1));
          if (items.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 40),
                EmptyState(
                  title: d.workStart == null ? l.dayOff : l.noAppointments,
                  icon: Icons.event_available_rounded,
                  action: TextButton(onPressed: () => context.push('/appointment/new?date=${d.date}'), child: Text(l.createAppointment)),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (_, i) => items[i].$2,
          );
        },
      ),
    );
  }

  static DateTime _roundUp(DateTime t) {
    final m = (t.minute / 15).ceil() * 15;
    return DateTime.utc(t.year, t.month, t.day, t.hour).add(Duration(minutes: m));
  }
}

class _WeekList extends ConsumerWidget {
  const _WeekList({required this.weekStart, required this.locale, required this.workdays});
  final DateTime weekStart;
  final String locale;
  final Set<int> workdays;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final currency = ref.watch(sessionProvider).value?.membership.currency ?? 'EUR';
    final v = ref.watch(rangeProvider((isoDate(weekStart), isoDate(weekStart.add(const Duration(days: 6))), '')));
    return AsyncView<List<Appointment>>(
      value: v,
      onRetry: () => ref.invalidate(rangeProvider),
      data: (all) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (var i = 0; i < 7; i++)
            Builder(
              builder: (_) {
                final d = weekStart.add(Duration(days: i));
                final items = all.where((a) => dateOnly(toBusinessLocal(a.startsAt)) == d).toList();
                final total = items.where((a) => a.isActive).fold<int>(0, (s, a) => s + a.netPriceMinor);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => ref.read(selectedDateProvider.notifier).set(d),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 18,
                              decoration: BoxDecoration(color: workdays.contains(d.weekday) ? c.green : c.weekend, borderRadius: BorderRadius.circular(2)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                toBeginningOfSentenceCase(DateFormat('EEEE, d MMMM', locale).format(d)),
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: workdays.contains(d.weekday) ? c.textPrimary : c.weekend),
                              ),
                            ),
                            if (total > 0) Text(formatMoney(total, currency, locale), style: TextStyle(color: c.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 4),
                        child: Text(workdays.contains(d.weekday) ? l.noAppointments : l.dayOff, style: TextStyle(color: c.textSecondary)),
                      ),
                    for (final a in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppointmentCard(appointment: a, currency: currency, locale: locale, onTap: () => context.push('/appointment/${a.id}')),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _Feed extends ConsumerWidget {
  const _Feed({required this.query, required this.locale});
  final String query, locale;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final currency = ref.watch(sessionProvider).value?.membership.currency ?? 'EUR';
    final today = businessToday();
    final from = query.isEmpty ? today : today.subtract(const Duration(days: 365));
    final v = ref.watch(rangeProvider((isoDate(from), isoDate(today.add(const Duration(days: 60))), query)));
    return AsyncView<List<Appointment>>(
      value: v,
      onRetry: () => ref.invalidate(rangeProvider),
      data: (all) {
        if (all.isEmpty) return EmptyState(title: l.noAppointments, icon: Icons.event_note_rounded);
        final groups = <DateTime, List<Appointment>>{};
        for (final a in all) {
          groups.putIfAbsent(dateOnly(toBusinessLocal(a.startsAt)), () => []).add(a);
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            for (final e in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                child: Text(
                  toBeginningOfSentenceCase(DateFormat('EEEE, d MMMM', locale).format(e.key)),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textSecondary),
                ),
              ),
              for (final a in e.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppointmentCard(appointment: a, currency: currency, locale: locale, onTap: () => context.push('/appointment/${a.id}')),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.revenue, required this.onToday, required this.onSearch});
  final String? revenue;
  final VoidCallback onToday, onSearch;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: l.search,
            onPressed: onSearch,
            icon: Icon(Icons.search_rounded, color: c.primary, size: 32),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.dayRevenue, style: TextStyle(fontSize: 15, color: c.textSecondary)),
                Text(revenue ?? '—', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          TextButton(
            onPressed: onToday,
            child: Text(l.today, style: TextStyle(fontSize: 21, color: c.primary)),
          ),
        ],
      ),
    );
  }
}
