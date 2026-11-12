import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';

/// Fixed bottom navigation; each tab keeps its own navigation stack (StatefulShellRoute).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: shell,
      bottomNavigationBar: AppBottomNavigation(
        index: shell.currentIndex,
        onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        items: [
          (Icons.grid_view_rounded, l.tabHome),
          (Icons.calendar_month_rounded, l.tabSchedule),
          (Icons.sms_rounded, l.tabChats),
          (Icons.menu_rounded, l.tabMore),
        ],
      ),
    );
  }
}

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({super.key, required this.index, required this.onTap, required this.items});
  final int index;
  final ValueChanged<int> onTap;
  final List<(IconData, String)> items;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final inactive = Theme.of(context).brightness == Brightness.light ? const Color(0xFF9E9EA6) : const Color(0xFF7A7982);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light ? const Color(0xFFF7F7F7) : c.surface,
        border: Border(top: BorderSide(color: c.divider, width: 0.6)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == index,
                    button: true,
                    label: items[i].$2,
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(items[i].$1, size: 30, color: i == index ? c.primary : inactive),
                          const SizedBox(height: 4),
                          Text(items[i].$2, style: TextStyle(fontSize: 13, color: i == index ? c.primary : inactive)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
