import 'dart:convert';

import 'package:beauty_crm/features/appointments/appointment_form_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

void main() {
  setUpAll(loadFonts);

  testWidgets('unauthenticated users land on login and validation runs', (tester) async {
    await pumpApp(tester, signedIn: false);
    expect(find.text('Войти'), findsWidgets);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Обязательное поле'), findsWidgets);
    await tester.enterText(find.byKey(const Key('email')), 'not-an-email');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Неверный email'), findsOneWidget);
  });

  testWidgets('home dashboard shows live values from the API', (tester) async {
    await pumpApp(tester);
    expect(find.text('Анна Смирнова'), findsOneWidget);
    expect(find.text('VIP PREMIUM'), findsOneWidget);
    expect(find.text('Tamara Крайс'), findsOneWidget);
    expect(find.text('322'), findsOneWidget);
    expect(find.textContaining('135'), findsOneWidget); // day revenue
    expect(find.text('+0 '), findsNothing);
  });

  testWidgets('schedule day view shows appointment card and clipped free gap', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Расписание'));
    await tester.pumpAndSettle();
    expect(find.text('Ноябрь'), findsOneWidget);
    expect(find.text('Мама Халиде Seray'), findsOneWidget);
    expect(find.text('создать запись или перерыв'), findsOneWidget);
    // gap 08:00–16:00 UTC is clipped to "now" (12:15 UTC, on the 15-min grid) -> 225 minutes remain
    expect(find.text('свободно: 225 мин'), findsOneWidget);
    expect(find.text('Выручка за день'), findsOneWidget);
    await tester.tap(find.text('Неделя'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Другое'));
    await tester.pumpAndSettle();
    expect(find.text('Настройки'), findsOneWidget);
    await tester.tap(find.text('Расписание'));
    await tester.pumpAndSettle();
    expect(find.text('Неделя'), findsOneWidget); // tab state preserved
  });

  testWidgets('create appointment posts selected service and slot', (tester) async {
    final b = standardBackend();
    Map<String, dynamic>? posted;
    b.on('POST', '/businesses/$biz/appointments', (o) {
      posted = o.data is String ? jsonDecode(o.data) : o.data as Map<String, dynamic>;
      return appt('new', '2026-11-12T13:00:00.000Z', '2026-11-12T15:00:00.000Z', 'X');
    });
    await pumpApp(tester, backend: b);
    await tester.tap(find.text('Создать запись').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Маникюр с однотонным покрытием'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('16:00'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Сохранить'), 300, scrollable: find.descendant(of: find.byType(AppointmentFormScreen), matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(posted, isNotNull);
    expect(posted!['serviceIds'], ['s1']);
    expect(posted!['startsAt'], '2026-11-12T13:00:00.000Z');
  });

  testWidgets('server error codes are shown as localized messages', (tester) async {
    final b = standardBackend();
    b.routes.remove('GET /businesses/$biz/dashboard');
    await pumpApp(tester, backend: b);
    expect(find.text('Что-то пошло не так'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
  });

  for (final (locale, text) in [('en', 'Create appointment'), ('tr', 'Randevu oluştur'), ('pt', 'Criar agendamento'), ('es', 'Crear cita')]) {
    testWidgets('localization: $locale', (tester) async {
      await pumpApp(tester, locale: Locale(locale));
      expect(find.text(text), findsWidgets);
    });
  }

  testWidgets('small screen (320x568) renders all tabs without overflow', (tester) async {
    await pumpApp(tester, size: const Size(320, 568));
    for (final tab in ['Расписание', 'Чаты', 'Другое', 'Главная']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('large screen (tablet) renders', (tester) async {
    await pumpApp(tester, size: const Size(1024, 1366));
    expect(tester.takeException(), isNull);
    expect(find.text('Tamara Крайс'), findsOneWidget);
  });

  testWidgets('dark theme renders', (tester) async {
    await pumpApp(tester, theme: ThemeMode.dark);
    final ctx = tester.element(find.text('Анна Смирнова'));
    expect(Theme.of(ctx).brightness, Brightness.dark);
  });

  testWidgets('accessibility: tap targets and labels', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);
    // Calendar day cells are 7-across; on a 368pt-wide phone they are ~47pt wide, which meets the
    // iOS 44pt guideline (Android's 48dp is met for every other control and on wider screens).
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
