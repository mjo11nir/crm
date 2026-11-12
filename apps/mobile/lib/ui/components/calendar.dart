import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/theme.dart';

/// Narrow weekday labels starting Monday, e.g. П В С Ч П С В.
List<String> narrowWeekdays(String locale) {
  final monday = DateTime(2024, 1, 1);
  return [for (var i = 0; i < 7; i++) DateFormat('EEEEE', locale).format(monday.add(Duration(days: i)))];
}

enum DayStyle { selectedBlack, selectedTeal }

/// One day number with optional dots (grey = staff booking, green = online booking).
class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    super.key,
    required this.date,
    required this.selected,
    required this.isToday,
    required this.isWorkday,
    this.inMonth = true,
    this.isPast = false,
    this.staffDots = 0,
    this.onlineDots = 0,
    this.onTap,
    this.selectedStyle = DayStyle.selectedBlack,
    this.fontSize = 24,
  });
  final DateTime date;
  final bool selected, isToday, isWorkday, inMonth, isPast;
  final int staffDots, onlineDots;
  final VoidCallback? onTap;
  final DayStyle selectedStyle;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Color fg = isWorkday ? c.textPrimary : c.weekend;
    if (isToday && !selected && selectedStyle == DayStyle.selectedBlack) fg = c.primary;
    if (isPast && !selected) fg = isWorkday ? c.textPrimary.withValues(alpha: 0.6) : c.weekend.withValues(alpha: 0.6);
    if (!inMonth) fg = fg.withValues(alpha: 0.32);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selBg = selectedStyle == DayStyle.selectedBlack ? (dark ? Colors.white : Colors.black) : c.cyan;
    final selFg = selectedStyle == DayStyle.selectedBlack && dark ? Colors.black : Colors.white;
    final circle = fontSize * 1.75;
    return Semantics(
      button: true,
      selected: selected,
      label: DateFormat.yMMMMd().format(date),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: double.infinity),
            Container(
              width: circle,
              height: circle,
              alignment: Alignment.center,
              decoration: selected
                  ? BoxDecoration(
                      color: selBg,
                      shape: BoxShape.circle,
                      boxShadow: selectedStyle == DayStyle.selectedTeal
                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 3))]
                          : null,
                    )
                  : null,
              child: Text(
                '${date.day}',
                style: TextStyle(fontSize: fontSize, fontWeight: selected ? FontWeight.w700 : FontWeight.w400, color: selected ? selFg : fg),
              ),
            ),
            SizedBox(
              height: 12, // keeps the tap target >= 48pt tall
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (staffDots > 0) _dot(const Color(0xFF6E6E73).withValues(alpha: inMonth ? 1 : 0.35)),
                  if (onlineDots > 0) _dot(c.green.withValues(alpha: inMonth ? 1 : 0.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color) => Container(
    width: 5,
    height: 5,
    margin: const EdgeInsets.symmetric(horizontal: 1.5),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Seven-day strip with weekday letters (Home screen).
class CalendarWeekStrip extends StatelessWidget {
  const CalendarWeekStrip({
    super.key,
    required this.weekStart,
    required this.selected,
    required this.today,
    required this.workdays,
    required this.onSelect,
    required this.locale,
  });
  final DateTime weekStart, selected, today;
  final Set<int> workdays;
  final ValueChanged<DateTime> onSelect;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final labels = narrowWeekdays(locale);
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(labels[i].toUpperCase(), style: TextStyle(fontSize: 18, color: workdays.contains(i + 1) ? c.textPrimary : c.weekend)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Builder(
                  builder: (_) {
                    final d = weekStart.add(Duration(days: i));
                    return CalendarDayCell(
                      date: d,
                      selected: dateOnly(d) == dateOnly(selected),
                      isToday: dateOnly(d) == dateOnly(today),
                      isWorkday: workdays.contains(d.weekday),
                      onTap: () => onSelect(d),
                      fontSize: 21,
                    );
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Month grid (Schedule screen). Collapsible to the selected week.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.selected,
    required this.today,
    required this.workdays,
    required this.dots,
    required this.onSelect,
    required this.locale,
    this.collapsed = false,
  });
  final DateTime month, selected, today;
  final Set<int> workdays;
  final Map<String, ({int total, int online})> dots;
  final ValueChanged<DateTime> onSelect;
  final String locale;
  final bool collapsed;

  static DateTime gridStart(DateTime month) => startOfWeek(DateTime(month.year, month.month, 1));
  static DateTime gridEnd(DateTime month) => gridStart(month).add(const Duration(days: 41));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final labels = narrowWeekdays(locale);
    final start = gridStart(month);
    final weeks = <List<DateTime>>[];
    for (var w = 0; w < 6; w++) {
      weeks.add([for (var d = 0; d < 7; d++) DateTime(start.year, start.month, start.day + w * 7 + d)]);
    }
    final visible = collapsed ? weeks.where((w) => w.any((d) => dateOnly(d) == dateOnly(selected))).toList() : weeks;
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(labels[i].toLowerCase(), style: TextStyle(fontSize: 13, color: c.textPrimary.withValues(alpha: 0.75))),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (final week in visible)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                for (final d in week)
                  Expanded(
                    child: Builder(
                      builder: (_) {
                        final key = isoDate(d);
                        final dot = dots[key];
                        return CalendarDayCell(
                          date: d,
                          selected: dateOnly(d) == dateOnly(selected),
                          isToday: dateOnly(d) == dateOnly(today),
                          isWorkday: workdays.contains(d.weekday),
                          inMonth: d.month == month.month,
                          isPast: dateOnly(d).isBefore(dateOnly(today)),
                          staffDots: dot == null ? 0 : dot.total - dot.online,
                          onlineDots: dot?.online ?? 0,
                          selectedStyle: DayStyle.selectedTeal,
                          fontSize: 21,
                          onTap: () => onSelect(d),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
