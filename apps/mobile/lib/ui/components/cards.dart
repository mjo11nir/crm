import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import 'components.dart';

/// Schedule day-view appointment card (bordered, avatar with reminder badge).
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({super.key, required this.appointment, required this.currency, required this.locale, this.onTap});
  final Appointment appointment;
  final String currency, locale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = appointment;
    final l = AppLocalizations.of(context);
    final cancelled = a.status == 'CANCELLED' || a.status == 'NO_SHOW';
    return AppCard(
      bordered: true,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: Opacity(
        opacity: cancelled ? 0.5 : 1,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    hhmm(a.startsAt, ''),
                    style: TextStyle(fontSize: 19, color: c.textPrimary, decoration: cancelled ? TextDecoration.lineThrough : null),
                  ),
                  const SizedBox(height: 2),
                  Text(hhmm(a.endsAt, ''), style: TextStyle(fontSize: 17, color: c.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.clientName ?? l.noClient,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 21, color: c.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    a.serviceNames.join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 17, color: c.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(formatMoney(a.netPriceMinor, currency, locale), style: TextStyle(fontSize: 17, color: c.textSecondary)),
                      if (a.status != 'BOOKED') ...[const SizedBox(width: 8), StatusChip(status: a.status)],
                    ],
                  ),
                ],
              ),
            ),
            Avatar(size: 58, badge: a.clientPhone != null && !cancelled),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    final (label, color) = switch (status) {
      'CONFIRMED' => (l.statusCONFIRMED, c.cyan),
      'COMPLETED' => (l.statusCOMPLETED, c.green),
      'CANCELLED' => (l.statusCANCELLED, c.weekend),
      'NO_SHOW' => (l.statusNO_SHOW, c.pink),
      _ => (l.statusBOOKED, c.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// "18:15 создать запись или перерыв / свободно: 45 мин".
class FreeGapCard extends StatelessWidget {
  const FreeGapCard({super.key, required this.gap, this.onTap});
  final FreeGap gap;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    return AppCard(
      bordered: true,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              hhmm(gap.start, ''),
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 19, color: c.primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.createOrBreak,
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w500, color: c.primary),
                ),
                const SizedBox(height: 4),
                Text(l.freeMinutes(gap.minutes), style: TextStyle(fontSize: 17, color: c.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact appointment row used on Home.
class HomeAppointmentRow extends StatelessWidget {
  const HomeAppointmentRow({super.key, required this.appointment, this.onTap});
  final Appointment appointment;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = appointment;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 62,
                  child: Text(
                    hhmm(a.startsAt, ''),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 18, color: c.textPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    a.clientName ?? AppLocalizations.of(context).noClient,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 18, color: c.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                SizedBox(
                  width: 62,
                  child: Text(
                    hhmm(a.endsAt, ''),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 16, color: c.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    a.serviceNames.join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FinanceSummaryCard extends StatelessWidget {
  const FinanceSummaryCard({
    super.key,
    required this.monthLabel,
    required this.totalMinor,
    required this.completedMinor,
    required this.plannedMinor,
    required this.currency,
    required this.locale,
    this.onTap,
  });
  final String monthLabel, currency, locale;
  final int totalMinor, completedMinor, plannedMinor;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    final total = completedMinor + plannedMinor;
    final greenFlex = total == 0 ? 0 : (completedMinor * 1000 / total).round();
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.finance, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text(monthLabel, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(formatMoney(totalMinor, currency, locale, compact: true), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),
          Semantics(
            label: '${l.earned} ${formatMoney(completedMinor, currency, locale)}, ${l.planned} ${formatMoney(plannedMinor, currency, locale)}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: total == 0
                    ? Container(color: c.divider)
                    : Row(
                        children: [
                          if (greenFlex > 0)
                            Expanded(
                              flex: greenFlex,
                              child: Container(color: c.green),
                            ),
                          if (greenFlex < 1000) ...[
                            const SizedBox(width: 2),
                            Expanded(
                              flex: 1000 - greenFlex,
                              child: Container(color: const Color(0xFFBF7BF0)),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ClientCard extends StatelessWidget {
  const ClientCard({super.key, required this.client, this.onTap});
  final Client client;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListTile(
      onTap: onTap,
      leading: Avatar(size: 40, name: client.fullName),
      title: Text(client.fullName, style: TextStyle(fontSize: 17, color: c.textPrimary)),
      subtitle: Text(
        [client.phone, if (client.tags.isNotEmpty) client.tags.join(', ')].whereType<String>().join(' · '),
        style: TextStyle(color: c.textSecondary),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: c.textSecondary),
    );
  }
}

class ServiceCard extends StatelessWidget {
  const ServiceCard({super.key, required this.service, required this.currency, required this.locale, this.onTap});
  final Service service;
  final String currency, locale;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    return ListTile(
      onTap: onTap,
      title: Text(service.name, style: TextStyle(fontSize: 17, color: service.isActive ? c.textPrimary : c.textSecondary)),
      subtitle: Text(
        '${l.minutesShort(service.durationMinutes)}${service.category != null ? ' · ${service.category}' : ''}',
        style: TextStyle(color: c.textSecondary),
      ),
      trailing: Text(formatMoney(service.priceMinor, currency, locale), style: TextStyle(fontSize: 16, color: c.textPrimary)),
    );
  }
}

/// The shareable free-slot card (rendered to PNG for social networks).
class AvailabilityCard extends StatelessWidget {
  const AvailabilityCard({super.key, required this.slots, required this.themeColor, required this.locale});
  final FreeSlots slots;
  final Color themeColor;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final light = Color.lerp(themeColor, Colors.white, 0.35)!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [themeColor, light]),
            ),
            child: Stack(
              children: [
                Positioned(right: -8, top: -6, child: Icon(Icons.auto_awesome_rounded, size: 96, color: Colors.white.withValues(alpha: 0.10))),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Text(l.bookNow, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 15)),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Avatar(size: 70, logo: true),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Text(
                                slots.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w500),
                              ),
                            ),
                            for (final (t, a, pad) in [(slots.phone, 0.8, 0.0), (slots.locationName, 0.8, 0.0), (slots.address, 0.65, 120.0)])
                              if (t != null)
                                Padding(
                                  padding: EdgeInsets.only(right: pad),
                                  child: Text(
                                    t,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.white.withValues(alpha: a), fontSize: 15),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 16, 0, 8),
            child: Text(
              l.freeTimeForBooking,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF444444)),
            ),
          ),
          if (slots.days.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 4, 16, 20),
              child: Text(l.noFreeTime, style: const TextStyle(color: Color(0xFF777777))),
            ),
          for (var i = 0; i < slots.days.length; i++)
            Container(
              margin: const EdgeInsets.only(left: 26),
              padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
              decoration: BoxDecoration(
                border: i < slots.days.length - 1
                    ? const Border(
                        bottom: BorderSide(color: Color(0xFFDDDDDD), width: 1, style: BorderStyle.solid),
                      )
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(
                      DateFormat('EE, d MMM', locale).format(DateTime.parse(slots.days[i].date)),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF555555)),
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        for (final t in slots.days[i].times)
                          Text(t.startsWith('0') ? t.substring(1) : t, style: const TextStyle(fontSize: 16, color: Color(0xFF555555))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

/// Pastel quick action used on the Home screen.
class QuickAction extends StatelessWidget {
  const QuickAction({super.key, required this.icon, required this.label, required this.background, required this.foreground, required this.onTap});
  final IconData icon;
  final String label;
  final Color background, foreground;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            ColoredIconTile(icon: icon, background: background, foreground: foreground, size: 66, radius: 20),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 15, height: 1.2)),
          ],
        ),
      ),
    );
  }
}
