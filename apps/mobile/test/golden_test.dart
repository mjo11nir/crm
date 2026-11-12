// Visual regression tests for the screens that mirror the reference screenshots
// (docs/reference/*.jpg). Deterministic: fixed clock, fixed data, bundled Inter font,
// 368x800 logical @2x (same geometry as the 736x1600 references).
// Regenerate intentionally with: flutter test --update-goldens test/golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

void main() {
  setUpAll(loadFonts);

  testWidgets('home (ref 2)', (tester) async {
    await pumpApp(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/home.png'));
  });

  testWidgets('schedule day (ref 1)', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Расписание'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/schedule_day.png'));
  });

  testWidgets('settings (ref 4)', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Другое'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/settings.png'));
  });

  testWidgets('free slots share card (ref 3, 5)', (tester) async {
    await pumpApp(tester, size: const Size(368, 1400));
    await tester.tap(find.text('Свободные окна'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/free_slots.png'));
  });

  testWidgets('home dark theme', (tester) async {
    await pumpApp(tester, theme: ThemeMode.dark);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/home_dark.png'));
  });
}
