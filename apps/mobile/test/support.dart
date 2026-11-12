import 'dart:convert';
import 'dart:io';

import 'package:beauty_crm/app.dart';
import 'package:beauty_crm/core/api_client.dart';
import 'package:beauty_crm/core/cache.dart';
import 'package:beauty_crm/core/format.dart';
import 'package:beauty_crm/core/token_store.dart';
import 'package:beauty_crm/data/repository.dart';
import 'package:beauty_crm/state/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

/// Fixed clock: Thursday 12 Nov 2026, 15:15 Istanbul (12:15 UTC).
final fixedNow = DateTime.utc(2026, 11, 12, 12, 15);

/// Records requests and answers from an in-memory route table — no network.
class FakeBackend implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final Map<String, Object? Function(RequestOptions)> routes = {};

  void on(String method, String pathPattern, Object? Function(RequestOptions) handler) => routes['$method $pathPattern'] = handler;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    requests.add(o);
    for (final e in routes.entries) {
      final parts = e.key.split(' ');
      if (parts[0] == o.method && RegExp('^${parts[1]}\$').hasMatch(o.path)) {
        final r = e.value(o);
        if (r is ResponseBody) return r;
        return ResponseBody.fromString(
          jsonEncode(r),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
    }
    return ResponseBody.fromString(
      jsonEncode({'message': 'no fake route for ${o.method} ${o.path}'}),
      404,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const biz = 'b0000000-0000-0000-0000-000000000001';

Map<String, dynamic> appt(String id, String start, String end, String client, {int price = 4500, String status = 'BOOKED', String source = 'STAFF'}) => {
  'id': id,
  'startsAt': start,
  'endsAt': end,
  'status': status,
  'source': source,
  'clientId': 'c-$id',
  'client': {'fullName': client, 'phone': '+90 533 000 00 00'},
  'services': [
    {'serviceId': 's1', 'nameSnapshot': 'Маникюр с однотонным покрытием'},
  ],
  'priceMinor': price,
  'netPriceMinor': price,
  'balanceMinor': price,
  'version': 1,
  'payments': [],
};

FakeBackend standardBackend() {
  final b = FakeBackend();
  b.on(
    'GET',
    '/auth/me',
    (_) => {
      'id': 'u1',
      'email': 'demo@example.test',
      'fullName': 'Анна Смирнова',
      'memberships': [
        {
          'role': 'OWNER',
          'business': {'id': biz, 'name': 'Лаванда Studio', 'slug': 'lavanda', 'timezone': 'Europe/Istanbul', 'currency': 'EUR'},
        },
      ],
    },
  );
  b.on(
    'GET',
    '/businesses/$biz/dashboard',
    (o) => {
      'profile': {'fullName': 'Анна Смирнова', 'businessName': 'Лаванда Studio'},
      'subscription': {'tier': 'VIP', 'status': 'ACTIVE', 'trialDaysLeft': null},
      'today': '2026-11-12',
      'selectedDate': o.queryParameters['date'],
      'currency': 'EUR',
      'week': [
        for (var i = 9; i <= 15; i++) {'date': '2026-11-$i', 'count': i < 13 ? 2 : 0},
      ],
      'appointments': [
        appt('a1', '2026-11-12T06:00:00.000Z', '2026-11-12T08:00:00.000Z', 'Tamara Крайс'),
        appt('a2', '2026-11-12T10:00:00.000Z', '2026-11-12T12:00:00.000Z', 'Кристина Суворова'),
        appt('a3', '2026-11-12T12:00:00.000Z', '2026-11-12T14:00:00.000Z', 'Елена Герасимова'),
      ],
      'dayRevenueMinor': 13500,
      'clients': {'total': 322, 'newThisMonth': 0},
      'finance': {'month': '2026-11', 'totalMinor': 234500, 'completedMinor': 120000, 'plannedMinor': 114500},
    },
  );
  b.on(
    'GET',
    '/businesses/$biz/employees',
    (_) => [
      {
        'id': 'e1',
        'schedules': [
          for (final wd in [1, 2, 3, 4]) {'weekday': wd, 'startMinute': 540, 'endMinute': 1140, 'locationId': 'l1'},
        ],
      },
    ],
  );
  b.on(
    'GET',
    '/businesses/$biz/calendar/dots',
    (_) => {
      for (final d in ['02', '03', '04', '05', '09', '10', '11', '16', '17', '19', '20', '23', '24', '25', '26', '27', '30'])
        '2026-11-$d': {'total': 2, 'online': d.endsWith('6') || d.endsWith('3') ? 1 : 0},
      '2026-11-12': {'total': 1, 'online': 0},
    },
  );
  b.on(
    'GET',
    '/businesses/$biz/calendar/day',
    (o) => {
      'date': o.queryParameters['date'],
      'timezone': 'Europe/Istanbul',
      'currency': 'EUR',
      'employeeId': 'e1',
      'working': [
        {'start': '2026-11-12T06:00:00.000Z', 'end': '2026-11-12T16:00:00.000Z'},
      ],
      'freeGaps': [
        {'start': '2026-11-12T08:00:00.000Z', 'end': '2026-11-12T16:00:00.000Z', 'minutes': 480},
      ],
      'appointments': [appt('a0', '2026-11-12T06:00:00.000Z', '2026-11-12T08:00:00.000Z', 'Мама Халиде Seray')],
      'revenueMinor': 4500,
    },
  );
  b.on(
    'GET',
    '/businesses/$biz',
    (_) => {
      'id': biz,
      'name': 'Лаванда Studio',
      'slug': 'lavanda',
      'currency': 'EUR',
      'timezone': 'Europe/Istanbul',
      'onlineBookingEnabled': true,
      'waitlistEnabled': true,
      'minNoticeMinutes': 60,
      'maxHorizonDays': 60,
      'slotStepMinutes': 15,
      'locations': [
        {'id': 'l1', 'name': 'Iskele', 'address': 'Long beach, Iskele'},
      ],
      'employees': [],
    },
  );
  b.on(
    'GET',
    '/businesses/$biz/services',
    (_) => [
      {
        'id': 's1',
        'name': 'Маникюр с однотонным покрытием',
        'durationMinutes': 120,
        'priceMinor': 4500,
        'depositMinor': 0,
        'bufferMinutes': 0,
        'onlineBookable': true,
        'isActive': true,
      },
    ],
  );
  b.on(
    'GET',
    '/businesses/$biz/free-slots',
    (_) => {
      'card': {'name': 'Анна Смирнова', 'phone': '+90 500 000 00 00', 'locationName': 'Iskele', 'address': 'Long beach, Iskele'},
      'bookingUrl': 'https://booking.example.com/lavanda',
      'durationMinutes': 120,
      'days': [
        {
          'date': '2026-11-19',
          'times': ['12:00', '14:00'],
        },
        {
          'date': '2026-11-20',
          'times': ['09:00', '11:00', '13:00'],
        },
        {
          'date': '2026-11-23',
          'times': ['11:00', '13:00', '15:00', '17:00'],
        },
        {
          'date': '2026-11-24',
          'times': ['09:00', '11:00', '13:00', '15:00', '17:00'],
        },
      ],
    },
  );
  b.on(
    'GET',
    '/businesses/$biz/availability',
    (_) => {
      'employeeId': 'e1',
      'durationMinutes': 120,
      'days': [
        {
          'date': '2026-11-12',
          'slots': [
            {'start': '2026-11-12T13:00:00.000Z', 'end': '2026-11-12T15:00:00.000Z', 'localDate': '2026-11-12', 'localTime': '16:00'},
          ],
        },
      ],
    },
  );
  b.on('GET', '/businesses/$biz/conversations', (_) => []);
  b.on('GET', '/businesses/$biz/appointments', (_) => [appt('w1', '2026-11-10T06:00:00.000Z', '2026-11-10T08:00:00.000Z', 'Tamara Крайс')]);
  return b;
}

Future<void> loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.view(File(f).readAsBytesSync().buffer)));
    }
    await loader.load();
  }

  await load('Inter', [
    'assets/fonts/Inter_400Regular.ttf',
    'assets/fonts/Inter_500Medium.ttf',
    'assets/fonts/Inter_600SemiBold.ttf',
    'assets/fonts/Inter_700Bold.ttf',
  ]);
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
  final icons = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) await load('MaterialIcons', [icons.path]);
}

/// Pumps the full app (router, theme, l10n) against the fake backend.
Future<FakeBackend> pumpApp(
  WidgetTester tester, {
  FakeBackend? backend,
  Locale locale = const Locale('ru'),
  ThemeMode theme = ThemeMode.light,
  Size size = const Size(368, 800),
  bool signedIn = true,
}) async {
  appNow = () => fixedNow;
  setBusinessZone('Europe/Istanbul');
  await initializeDateFormatting();
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final b = backend ?? standardBackend();
  final tokens = MemoryTokenStore();
  if (signedIn) await tokens.write(Tokens('access', 'refresh'));
  final dio = Dio(BaseOptions(baseUrl: 'http://fake/api/v1'))..httpClientAdapter = b;
  final repo = CrmRepository(ApiClient(tokens, dio: dio), tokens, OfflineCache(null));
  final container = ProviderContainer(overrides: [repositoryProvider.overrideWithValue(repo)]);
  addTearDown(container.dispose);
  container.read(prefsProvider.notifier)
    ..setLocale(locale)
    ..setTheme(theme);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const BeautyCrmApp()));
  await tester.pumpAndSettle();
  return b;
}
