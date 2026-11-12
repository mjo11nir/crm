import 'dart:math';

import '../core/api_client.dart';
import '../core/cache.dart';
import '../core/token_store.dart';
import 'models.dart';

/// Single gateway to the backend. All business data comes from the API — no hardcoded values.
class CrmRepository {
  CrmRepository(this.api, this.tokens, this.cache);
  final ApiClient api;
  final TokenStore tokens;
  final OfflineCache cache;

  // ---------- auth ----------
  Future<void> login(String email, String password) async {
    final r = await api.post<Map<String, dynamic>>('/auth/login', data: {'email': email, 'password': password}, noAuth: true);
    await tokens.write(Tokens(r['accessToken'], r['refreshToken']));
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required String businessName,
    String? phone,
    String? timezone,
    String? currency,
  }) async {
    final r = await api.post<Map<String, dynamic>>(
      '/auth/register',
      noAuth: true,
      data: {
        'email': email,
        'password': password,
        'fullName': fullName,
        'businessName': businessName,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'timezone': ?timezone,
        'currency': ?currency,
      },
    );
    await tokens.write(Tokens(r['accessToken'], r['refreshToken']));
  }

  Future<void> logout() async {
    final t = await tokens.read();
    if (t != null) {
      try {
        await api.post('/auth/logout', data: {'refreshToken': t.refreshToken}, noAuth: true);
      } catch (_) {}
    }
    await tokens.clear();
  }

  Future<void> logoutAll() async {
    await api.post('/auth/logout-all');
    await tokens.clear();
  }

  Future<void> deleteAccount(String password) async {
    await api.delete('/auth/account', data: {'password': password});
    await tokens.clear();
  }

  Future<bool> hasSession() async => (await tokens.read()) != null;

  Future<Me> me() async => Me.fromJson(await api.get('/auth/me'));

  // ---------- read with offline fallback ----------
  Future<T> _cached<T>(String key, Future<Object?> Function() fetch, T Function(Object?) parse) async {
    try {
      final v = await fetch();
      await cache.put(key, v);
      return parse(v);
    } on ApiException catch (e) {
      final c = cache.get(key);
      if (e.isNetwork && c != null) return parse(c.value);
      rethrow;
    }
  }

  Future<Dashboard> dashboard(String b, String date) =>
      _cached('dash:$b:$date', () => api.get('/businesses/$b/dashboard', query: {'date': date}), (v) => Dashboard.fromJson(v as Map<String, dynamic>));

  Future<DayView> day(String b, String date) =>
      _cached('day:$b:$date', () => api.get('/businesses/$b/calendar/day', query: {'date': date}), (v) => DayView.fromJson(v as Map<String, dynamic>));

  Future<Map<String, ({int total, int online})>> dots(String b, String from, String to) =>
      _cached('dots:$b:$from:$to', () => api.get('/businesses/$b/calendar/dots', query: {'from': from, 'to': to}), (v) {
        final m = v as Map<String, dynamic>;
        return {for (final e in m.entries) e.key: (total: (e.value['total'] as num).toInt(), online: (e.value['online'] as num).toInt())};
      });

  Future<List<Appointment>> appointments(String b, String from, String to, {String? q}) => _cached(
    'appts:$b:$from:$to:${q ?? ''}',
    () => api.get('/businesses/$b/appointments', query: {'from': from, 'to': to, if (q != null && q.isNotEmpty) 'q': q}),
    (v) => [for (final a in v as List) Appointment.fromJson(a)],
  );

  Future<Appointment> appointment(String b, String id) async => Appointment.fromJson(await api.get('/businesses/$b/appointments/$id'));

  Future<List<Service>> services(String b, {bool includeInactive = false}) => _cached(
    'services:$b:$includeInactive',
    () => api.get('/businesses/$b/services', query: {if (includeInactive) 'includeInactive': 'true'}),
    (v) => [for (final s in v as List) Service.fromJson(s)],
  );

  Future<({List<Client> items, int total})> clients(String b, {String? q, bool archived = false}) => _cached(
    'clients:$b:${q ?? ''}:$archived',
    () => api.get('/businesses/$b/clients', query: {if (q != null && q.isNotEmpty) 'q': q, if (archived) 'archived': 'true', 'take': 200}),
    (v) {
      final m = v as Map<String, dynamic>;
      return (items: [for (final c in m['items'] as List) Client.fromJson(c)], total: (m['total'] as num).toInt());
    },
  );

  Future<ClientProfile> clientProfile(String b, String id) async => ClientProfile.fromJson(await api.get('/businesses/$b/clients/$id'));

  Future<Business> business(String b) => _cached('biz:$b', () => api.get('/businesses/$b'), (v) => Business(raw: v as Map<String, dynamic>));

  Future<List<Map<String, dynamic>>> employees(String b) async => [...(await api.get<List>('/businesses/$b/employees')).cast<Map<String, dynamic>>()];

  Future<FreeSlots> freeSlots(String b, {required String from, required String to, String? serviceId, String? locationId, int? duration}) async =>
      FreeSlots.fromJson(
        await api.get('/businesses/$b/free-slots', query: {'from': from, 'to': to, 'serviceId': ?serviceId, 'locationId': ?locationId, 'duration': ?duration}),
      );

  Future<List<({String date, List<({DateTime start, String time})> slots})>> availability(
    String b, {
    required String from,
    required String to,
    required List<String> serviceIds,
  }) async {
    final r = await api.get<Map<String, dynamic>>('/businesses/$b/availability', query: {'from': from, 'to': to, 'serviceIds': serviceIds.join(',')});
    return [
      for (final d in r['days'] as List)
        (date: d['date'] as String, slots: [for (final s in d['slots'] as List) (start: DateTime.parse(s['start']).toUtc(), time: s['localTime'] as String)]),
    ];
  }

  Future<List<Conversation>> conversations(String b) async => [for (final c in await api.get<List>('/businesses/$b/conversations')) Conversation.fromJson(c)];
  Future<List<Message>> messages(String b, String c) async => [
    for (final m in await api.get<List>('/businesses/$b/conversations/$c/messages')) Message.fromJson(m),
  ];
  Future<void> sendMessage(String b, String c, String body) => api.post('/businesses/$b/conversations/$c/messages', data: {'body': body});
  Future<void> createConversation(String b, String title, String kind) => api.post('/businesses/$b/conversations', data: {'title': title, 'kind': kind});

  Future<Map<String, dynamic>> subscription(String b) async => await api.get('/businesses/$b/subscription');
  Future<List<Map<String, dynamic>>> notifications(String b) async => [...(await api.get<List>('/businesses/$b/notifications')).cast<Map<String, dynamic>>()];
  Future<List<Map<String, dynamic>>> waitlist(String b) async => [...(await api.get<List>('/businesses/$b/waitlist')).cast<Map<String, dynamic>>()];
  Future<Map<String, dynamic>> report(String b, String from, String to) async =>
      await api.get('/businesses/$b/finance/report', query: {'from': from, 'to': to});

  // ---------- writes (online only; never optimistic) ----------
  Future<Appointment> createAppointment(String b, Map<String, dynamic> body) async =>
      Appointment.fromJson(await api.post('/businesses/$b/appointments', data: body));
  Future<Appointment> updateAppointment(String b, String id, Map<String, dynamic> body) async =>
      Appointment.fromJson(await api.patch('/businesses/$b/appointments/$id', data: body));
  Future<Appointment> setStatus(String b, String id, String status) async =>
      Appointment.fromJson(await api.post('/businesses/$b/appointments/$id/status', data: {'status': status}));
  Future<void> recordPayment(String b, String id, String kind, String method, int amountMinor) =>
      api.post('/businesses/$b/appointments/$id/payments', data: {'kind': kind, 'method': method, 'amountMinor': amountMinor});
  Future<Client> createClient(String b, Map<String, dynamic> body) async => Client.fromJson(await api.post('/businesses/$b/clients', data: body));
  Future<Client> updateClient(String b, String id, Map<String, dynamic> body) async =>
      Client.fromJson(await api.patch('/businesses/$b/clients/$id', data: body));
  Future<void> archiveClient(String b, String id, bool archive) => api.post('/businesses/$b/clients/$id/${archive ? 'archive' : 'unarchive'}');
  Future<Service> createService(String b, Map<String, dynamic> body) async => Service.fromJson(await api.post('/businesses/$b/services', data: body));
  Future<Service> updateService(String b, String id, Map<String, dynamic> body) async =>
      Service.fromJson(await api.patch('/businesses/$b/services/$id', data: body));
  Future<void> deleteService(String b, String id) => api.delete('/businesses/$b/services/$id');
  Future<void> updateBusiness(String b, Map<String, dynamic> body) => api.patch('/businesses/$b', data: body);
  Future<void> createLocation(String b, String name, String? address) =>
      api.post('/businesses/$b/locations', data: {'name': name, if (address != null && address.isNotEmpty) 'address': address});
  Future<void> replaceSchedule(String b, String employeeId, List<ScheduleDay> days) => api.put(
    '/businesses/$b/employees/$employeeId/schedule',
    data: {
      'days': [for (final d in days) d.toJson()],
    },
  );

  static String newIdempotencyKey() {
    final r = Random.secure();
    return List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
  }
}
