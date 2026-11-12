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

/// Главная — dashboard (reference screenshot 2).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDateProvider);
    final dash = ref.watch(dashboardProvider(isoDate(selected)));
    final workdays = ref.watch(workdaysProvider).value ?? {1, 2, 3, 4, 5};
    final locale = Localizations.localeOf(context).toString();
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _PastelBackground()),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(dashboardProvider),
              child: AsyncView<Dashboard>(
                value: dash,
                onRetry: () => ref.invalidate(dashboardProvider),
                data: (d) => _HomeBody(d: d, selected: selected, workdays: workdays, locale: locale),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.d, required this.selected, required this.workdays, required this.locale});
  final Dashboard d;
  final DateTime selected;
  final Set<int> workdays;
  final String locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final today = DateTime.parse(d.today);
    final month = DateTime.parse('${d.month}-01');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // Header + week + appointments card
        Container(
          decoration: BoxDecoration(color: c.surface.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(18)),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(4, 4, 12, 12),
                decoration: BoxDecoration(
                  color: c.surface.withValues(alpha: 0.4),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(
                  children: [
                    const Avatar(size: 76, logo: true),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          if (d.tier != null) _TierBadge(tier: d.tier!, status: d.subscriptionStatus, trialDaysLeft: d.trialDaysLeft),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l.notifications,
                      onPressed: () => context.push('/notifications'),
                      icon: Icon(Icons.notifications_rounded, color: c.textPrimary, size: 30),
                    ),
                  ],
                ),
              ),
              Divider(color: c.divider, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                child: CalendarWeekStrip(
                  weekStart: startOfWeek(selected),
                  selected: selected,
                  today: today,
                  workdays: workdays,
                  locale: locale,
                  onSelect: (x) => ref.read(selectedDateProvider.notifier).set(x),
                ),
              ),
              if (d.appointments.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(workdays.contains(selected.weekday) ? l.noAppointments : l.dayOff, style: TextStyle(color: c.textSecondary, fontSize: 16)),
                )
              else
                for (final a in d.appointments) HomeAppointmentRow(appointment: a, onTap: () => context.push('/appointment/${a.id}')),
              Divider(color: c.divider, height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  l.revenueValue(formatMoney(d.dayRevenueMinor, d.currency, locale, compact: true)),
                  style: TextStyle(fontSize: 18, color: c.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          onTap: () => context.push('/appointment/new?date=${isoDate(selected)}'),
          padding: const EdgeInsets.symmetric(vertical: 26),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Text(l.createAppointment, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: AppCard(
                  onTap: () => context.go('/more/clients'),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.clients, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Text('${d.clientsTotal}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(l.totalInBase, style: const TextStyle(fontSize: 17)),
                      const SizedBox(height: 14),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '+${d.clientsNew} ',
                              style: TextStyle(color: c.green, fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                            TextSpan(text: l.newInMonth('${month.month}'), style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FinanceSummaryCard(
                  monthLabel: toBeginningOfSentenceCase(DateFormat('LLLL', locale).format(month)),
                  totalMinor: d.monthTotalMinor,
                  completedMinor: d.monthCompletedMinor,
                  plannedMinor: d.monthPlannedMinor,
                  currency: d.currency,
                  locale: locale,
                  onTap: () => context.go('/more/statistics'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: QuickAction(
                  icon: Icons.edit_calendar_rounded,
                  label: l.createAppointment,
                  background: c.tileOrange,
                  foreground: const Color(0xFFE9A21F),
                  onTap: () => context.push('/appointment/new?date=${isoDate(selected)}'),
                ),
              ),
              Expanded(
                child: QuickAction(
                  icon: Icons.calendar_view_day_rounded,
                  label: l.freeSlots,
                  background: c.tileOrange,
                  foreground: const Color(0xFFE9A21F),
                  onTap: () => context.push('/free-slots'),
                ),
              ),
              Expanded(
                child: QuickAction(
                  icon: Icons.sms_rounded,
                  label: l.notifications,
                  background: c.tileGreen,
                  foreground: c.green,
                  onTap: () => context.push('/notifications'),
                ),
              ),
              Expanded(
                child: QuickAction(
                  icon: Icons.help_rounded,
                  label: l.help,
                  background: c.tileGrey,
                  foreground: const Color(0xFF6C6C70),
                  onTap: () => context.go('/chats'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier, this.status, this.trialDaysLeft});
  final String tier;
  final String? status;
  final int? trialDaysLeft;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = status == 'EXPIRED'
        ? l.expired.toUpperCase()
        : tier == 'TRIAL'
        ? l.trialDaysLeft(trialDaysLeft ?? 0)
        : tier == 'VIP'
        ? 'VIP PREMIUM'
        : 'PREMIUM';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: status == 'EXPIRED' ? context.colors.weekend : Colors.black, borderRadius: BorderRadius.circular(12)),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.3),
      ),
    );
  }
}

/// Soft pastel gradient backdrop (original artwork: layered radial gradients).
class _PastelBackground extends StatelessWidget {
  const _PastelBackground();
  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) return ColoredBox(color: context.colors.background);
    Widget blob(Alignment a, Color col, double r) => Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(center: a, radius: r, colors: [col, col.withValues(alpha: 0)]),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFFF4E6F4)),
        blob(const Alignment(-1.0, -1.0), const Color(0xFFDCEFD9), 0.9),
        blob(const Alignment(1.0, -0.9), const Color(0xFFEBB8F0), 0.9),
        blob(const Alignment(-1.1, 0.2), const Color(0xFFF7C5DD), 0.8),
        blob(const Alignment(1.1, 0.3), const Color(0xFFF5E9C9), 0.7),
        blob(const Alignment(0.0, 1.0), const Color(0xFFF2D3E5), 0.9),
      ],
    );
  }
}
