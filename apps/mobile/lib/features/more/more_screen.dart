import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../ui/components/components.dart';

/// Другое → Профиль / Настройки (reference screenshot 4).
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final session = ref.watch(sessionProvider).value;
    final business = ref.watch(businessProvider).value;
    const orange = Color(0xFFF0A92E);
    const grey = Color(0xFFA7A7AC);
    return Scaffold(
      appBar: AppBar(title: Text(l.profile)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (session != null)
            SettingsGroup(
              indentDividers: 16,
              children: [
                SettingRow(
                  title: session.me.fullName,
                  subtitle: '${session.membership.businessName} · ${session.me.email}',
                  onTap: () => context.go('/more/account'),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(l.settings, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
          ),
          SettingsGroup(
            children: [
              SettingRow(icon: Icons.edit_calendar_rounded, iconColor: orange, title: l.scheduleAndPlace, onTap: () => context.go('/more/work-schedule')),
              SettingRow(icon: Icons.edit_note_rounded, iconColor: orange, title: l.onlineBooking, onTap: () => context.go('/more/online-booking')),
              SettingRow(
                icon: Icons.event_available_rounded,
                iconColor: orange,
                title: l.waitlist,
                value: business == null ? null : (business.waitlistEnabled ? l.on : l.off),
                onTap: () => context.go('/more/waitlist'),
              ),
            ],
          ),
          SettingsGroup(
            children: [
              SettingRow(
                icon: Icons.room_service_rounded,
                iconColor: const Color(0xFFA346E8),
                title: l.servicesAndProducts,
                onTap: () => context.go('/more/services'),
              ),
            ],
          ),
          SettingsGroup(
            children: [SettingRow(icon: Icons.language_rounded, iconColor: c.pink, title: l.webPage, onTap: () => context.go('/more/web-page'))],
          ),
          SettingsGroup(
            children: [
              SettingRow(icon: Icons.contacts_rounded, iconColor: const Color(0xFFF07FB0), title: l.clients, onTap: () => context.go('/more/clients')),
              SettingRow(icon: Icons.bar_chart_rounded, iconColor: c.cyan, title: l.statistics, onTap: () => context.go('/more/statistics')),
            ],
          ),
          SettingsGroup(
            children: [
              SettingRow(
                icon: Icons.chat_bubble_outline_rounded,
                iconColor: const Color(0xFF3FCB5D),
                title: l.clientNotifications,
                onTap: () => context.go('/more/client-notifications'),
              ),
              SettingRow(icon: Icons.notifications_none_rounded, iconColor: const Color(0xFF3FCB5D), title: l.alerts, onTap: () => context.go('/more/alerts')),
              SettingRow(
                icon: Icons.event_repeat_rounded,
                iconColor: const Color(0xFF3FCB5D),
                title: l.calendarSync,
                onTap: () => context.go('/more/calendar-sync'),
              ),
            ],
          ),
          SettingsGroup(
            children: [
              SettingRow(icon: Icons.format_paint_rounded, iconColor: grey, title: l.appearance, onTap: () => context.go('/more/appearance')),
              SettingRow(icon: Icons.translate_rounded, iconColor: grey, title: l.languageRegion, onTap: () => context.go('/more/language')),
              SettingRow(icon: Icons.workspace_premium_rounded, iconColor: grey, title: l.subscription, onTap: () => context.go('/more/subscription')),
            ],
          ),
          SettingsGroup(
            children: [SettingRow(title: l.logout, destructive: true, showChevron: false, onTap: () => ref.read(sessionProvider.notifier).logout())],
          ),
        ],
      ),
    );
  }
}
