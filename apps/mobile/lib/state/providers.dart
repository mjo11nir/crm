import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../data/models.dart';
import '../data/repository.dart';

/// Overridden in main() / tests.
final repositoryProvider = Provider<CrmRepository>((ref) => throw UnimplementedError('repositoryProvider must be overridden'));

class Session {
  Session(this.me, this.membership);
  final Me me;
  final Membership membership;
  String get businessId => membership.businessId;
}

class SessionNotifier extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() async {
    final repo = ref.read(repositoryProvider);
    if (!await repo.hasSession()) return null;
    try {
      final me = await repo.me();
      setBusinessZone(me.memberships.first.timezone);
      return Session(me, me.memberships.first);
    } catch (_) {
      return null;
    }
  }

  Future<void> login(String email, String password) async {
    await ref.read(repositoryProvider).login(email, password);
    ref.invalidateSelf();
    await future;
  }

  Future<void> register(Map<String, String?> f) async {
    await ref
        .read(repositoryProvider)
        .register(
          email: f['email']!,
          password: f['password']!,
          fullName: f['fullName']!,
          businessName: f['businessName']!,
          phone: f['phone'],
          timezone: f['timezone'],
          currency: f['currency'],
        );
    ref.invalidateSelf();
    await future;
  }

  Future<void> logout({bool everywhere = false}) async {
    final repo = ref.read(repositoryProvider);
    everywhere ? await repo.logoutAll() : await repo.logout();
    state = const AsyncData(null);
  }

  void expired() => state = const AsyncData(null);
}

final sessionProvider = AsyncNotifierProvider<SessionNotifier, Session?>(SessionNotifier.new);

String bizId(Ref ref) {
  final s = ref.watch(sessionProvider).value;
  if (s == null) throw StateError('Not signed in');
  return s.businessId;
}

/// Currently selected calendar date (shared between Home and Schedule).
class SelectedDate extends Notifier<DateTime> {
  @override
  DateTime build() => businessToday();
  void set(DateTime d) => state = dateOnly(d);
}

final selectedDateProvider = NotifierProvider<SelectedDate, DateTime>(SelectedDate.new);

final dashboardProvider = FutureProvider.autoDispose.family<Dashboard, String>((ref, date) => ref.read(repositoryProvider).dashboard(bizId(ref), date));
final dayProvider = FutureProvider.autoDispose.family<DayView, String>((ref, date) => ref.read(repositoryProvider).day(bizId(ref), date));
final dotsProvider = FutureProvider.autoDispose.family<Map<String, ({int total, int online})>, (String, String)>(
  (ref, r) => ref.read(repositoryProvider).dots(bizId(ref), r.$1, r.$2),
);
final rangeProvider = FutureProvider.autoDispose.family<List<Appointment>, (String, String, String)>(
  (ref, r) => ref.read(repositoryProvider).appointments(bizId(ref), r.$1, r.$2, q: r.$3),
);
final appointmentProvider = FutureProvider.autoDispose.family<Appointment, String>((ref, id) => ref.read(repositoryProvider).appointment(bizId(ref), id));
final servicesProvider = FutureProvider.autoDispose<List<Service>>((ref) => ref.read(repositoryProvider).services(bizId(ref), includeInactive: true));
final clientsProvider = FutureProvider.autoDispose.family<({List<Client> items, int total}), String>(
  (ref, q) => ref.read(repositoryProvider).clients(bizId(ref), q: q),
);
final clientProfileProvider = FutureProvider.autoDispose.family<ClientProfile, String>((ref, id) => ref.read(repositoryProvider).clientProfile(bizId(ref), id));
final businessProvider = FutureProvider.autoDispose<Business>((ref) => ref.read(repositoryProvider).business(bizId(ref)));
final conversationsProvider = FutureProvider.autoDispose<List<Conversation>>((ref) => ref.read(repositoryProvider).conversations(bizId(ref)));
final messagesProvider = FutureProvider.autoDispose.family<List<Message>, String>((ref, c) => ref.read(repositoryProvider).messages(bizId(ref), c));
final subscriptionProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) => ref.read(repositoryProvider).subscription(bizId(ref)));

/// Call after any appointment mutation so every calendar-derived screen refreshes.
void invalidateCalendar(WidgetRef ref) {
  ref.invalidate(dashboardProvider);
  ref.invalidate(dayProvider);
  ref.invalidate(dotsProvider);
  ref.invalidate(rangeProvider);
  ref.invalidate(appointmentProvider);
  ref.invalidate(clientProfileProvider);
}

/// Theme & locale preferences.
class AppPrefs {
  const AppPrefs({this.themeMode = ThemeMode.system, this.locale});
  final ThemeMode themeMode;
  final Locale? locale;
  AppPrefs copyWith({ThemeMode? themeMode, Locale? locale, bool clearLocale = false}) =>
      AppPrefs(themeMode: themeMode ?? this.themeMode, locale: clearLocale ? null : (locale ?? this.locale));
}

class PrefsNotifier extends Notifier<AppPrefs> {
  @override
  AppPrefs build() => const AppPrefs();
  void setTheme(ThemeMode m) => state = state.copyWith(themeMode: m);
  void setLocale(Locale? l) => state = l == null ? state.copyWith(clearLocale: true) : state.copyWith(locale: l);
}

final prefsProvider = NotifierProvider<PrefsNotifier, AppPrefs>(PrefsNotifier.new);

/// ISO weekdays on which the (first) specialist works — drives red/black day colouring.
final workdaysProvider = FutureProvider.autoDispose<Set<int>>((ref) async {
  final emps = await ref.read(repositoryProvider).employees(bizId(ref));
  if (emps.isEmpty) return {1, 2, 3, 4, 5};
  return {for (final s in (emps.first['schedules'] as List? ?? const [])) (s['weekday'] as num).toInt()};
});
