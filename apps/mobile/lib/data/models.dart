// Hand-written JSON models mirroring the API (services/api, OpenAPI at /api/docs).

DateTime _dt(Object? v) => DateTime.parse(v as String).toUtc();
DateTime? _dtn(Object? v) => v == null ? null : DateTime.parse(v as String).toUtc();
int _i(Object? v) => (v as num?)?.toInt() ?? 0;

class Membership {
  Membership({required this.businessId, required this.businessName, required this.role, required this.currency, required this.timezone, required this.slug});
  final String businessId, businessName, role, currency, timezone, slug;
}

class Me {
  Me({required this.id, required this.email, required this.fullName, this.phone, required this.memberships});
  final String id, email, fullName;
  final String? phone;
  final List<Membership> memberships;
  factory Me.fromJson(Map<String, dynamic> j) => Me(
    id: j['id'],
    email: j['email'],
    fullName: j['fullName'],
    phone: j['phone'],
    memberships: [
      for (final m in (j['memberships'] as List))
        Membership(
          businessId: m['business']['id'],
          businessName: m['business']['name'],
          role: m['role'],
          currency: m['business']['currency'],
          timezone: m['business']['timezone'],
          slug: m['business']['slug'],
        ),
    ],
  );
}

class Service {
  Service({
    required this.id,
    required this.name,
    this.description,
    required this.durationMinutes,
    required this.priceMinor,
    required this.depositMinor,
    required this.bufferMinutes,
    required this.onlineBookable,
    required this.isActive,
    this.category,
  });
  final String id, name;
  final String? description, category;
  final int durationMinutes, priceMinor, depositMinor, bufferMinutes;
  final bool onlineBookable, isActive;
  factory Service.fromJson(Map<String, dynamic> j) => Service(
    id: j['id'],
    name: j['name'],
    description: j['description'],
    durationMinutes: _i(j['durationMinutes']),
    priceMinor: _i(j['priceMinor']),
    depositMinor: _i(j['depositMinor']),
    bufferMinutes: _i(j['bufferMinutes']),
    onlineBookable: j['onlineBookable'] ?? true,
    isActive: j['isActive'] ?? true,
    category: (j['category'] as Map?)?['name'],
  );
}

class Client {
  Client({
    required this.id,
    required this.fullName,
    this.phone,
    this.email,
    this.notes,
    this.birthday,
    this.tags = const [],
    this.discountPercent = 0,
    this.archived = false,
  });
  final String id, fullName;
  final String? phone, email, notes, birthday;
  final List<String> tags;
  final int discountPercent;
  final bool archived;
  factory Client.fromJson(Map<String, dynamic> j) => Client(
    id: j['id'],
    fullName: j['fullName'],
    phone: j['phone'],
    email: j['email'],
    notes: j['notes'],
    birthday: (j['birthday'] as String?)?.substring(0, 10),
    tags: [...(j['tags'] as List? ?? const []).cast<String>()],
    discountPercent: _i(j['discountPercent']),
    archived: j['archivedAt'] != null,
  );
}

class Payment {
  Payment({required this.kind, required this.method, required this.amountMinor, required this.paidAt});
  final String kind, method;
  final int amountMinor;
  final DateTime paidAt;
  factory Payment.fromJson(Map<String, dynamic> j) =>
      Payment(kind: j['kind'], method: j['method'], amountMinor: _i(j['amountMinor']), paidAt: _dt(j['paidAt']));
}

class Appointment {
  Appointment({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.source,
    this.clientId,
    this.clientName,
    this.clientPhone,
    required this.serviceNames,
    required this.serviceIds,
    required this.priceMinor,
    required this.netPriceMinor,
    required this.balanceMinor,
    required this.version,
    this.notes,
    this.payments = const [],
    this.employeeId,
  });
  final String id, status, source;
  final DateTime startsAt, endsAt;
  final String? clientId, clientName, clientPhone, notes, employeeId;
  final List<String> serviceNames, serviceIds;
  final int priceMinor, netPriceMinor, balanceMinor, version;
  final List<Payment> payments;

  bool get isActive => status == 'BOOKED' || status == 'CONFIRMED' || status == 'COMPLETED';
  int get durationMinutes => endsAt.difference(startsAt).inMinutes;

  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
    id: j['id'],
    startsAt: _dt(j['startsAt']),
    endsAt: _dt(j['endsAt']),
    status: j['status'],
    source: j['source'] ?? 'STAFF',
    clientId: j['clientId'],
    clientName: (j['client'] as Map?)?['fullName'] ?? j['clientName'],
    clientPhone: (j['client'] as Map?)?['phone'],
    serviceNames: j['services'] is String ? [j['services'] as String] : [for (final s in (j['services'] as List? ?? const [])) s['nameSnapshot'] as String],
    serviceIds: j['services'] is List ? [for (final s in j['services'] as List) s['serviceId'] as String] : const [],
    priceMinor: _i(j['priceMinor'] ?? j['netPriceMinor']),
    netPriceMinor: _i(j['netPriceMinor']),
    balanceMinor: _i(j['balanceMinor']),
    version: _i(j['version'] ?? 1),
    notes: j['notes'],
    payments: [for (final p in (j['payments'] as List? ?? const [])) Payment.fromJson(p)],
    employeeId: j['employeeId'],
  );
}

class FreeGap {
  FreeGap(this.start, this.end, this.minutes);
  final DateTime start, end;
  final int minutes;
}

class DayView {
  DayView({
    required this.date,
    required this.appointments,
    required this.gaps,
    required this.revenueMinor,
    required this.currency,
    this.workStart,
    this.workEnd,
  });
  final String date, currency;
  final List<Appointment> appointments;
  final List<FreeGap> gaps;
  final int revenueMinor;
  final DateTime? workStart, workEnd;
  factory DayView.fromJson(Map<String, dynamic> j) {
    final working = j['working'] as List;
    return DayView(
      date: j['date'],
      currency: j['currency'],
      appointments: [for (final a in j['appointments'] as List) Appointment.fromJson(a)],
      gaps: [for (final g in j['freeGaps'] as List) FreeGap(_dt(g['start']), _dt(g['end']), _i(g['minutes']))],
      revenueMinor: _i(j['revenueMinor']),
      workStart: working.isEmpty ? null : _dt(working.first['start']),
      workEnd: working.isEmpty ? null : _dt(working.last['end']),
    );
  }
}

class Dashboard {
  Dashboard({
    required this.fullName,
    required this.businessName,
    this.tier,
    this.subscriptionStatus,
    this.trialDaysLeft,
    required this.today,
    required this.selectedDate,
    required this.currency,
    required this.week,
    required this.appointments,
    required this.dayRevenueMinor,
    required this.clientsTotal,
    required this.clientsNew,
    required this.monthTotalMinor,
    required this.monthCompletedMinor,
    required this.monthPlannedMinor,
    required this.month,
  });
  final String fullName, businessName, today, selectedDate, currency, month;
  final String? tier, subscriptionStatus;
  final int? trialDaysLeft;
  final List<({String date, int count})> week;
  final List<Appointment> appointments;
  final int dayRevenueMinor, clientsTotal, clientsNew, monthTotalMinor, monthCompletedMinor, monthPlannedMinor;

  factory Dashboard.fromJson(Map<String, dynamic> j) => Dashboard(
    fullName: j['profile']['fullName'],
    businessName: j['profile']['businessName'],
    tier: j['subscription']?['tier'],
    subscriptionStatus: j['subscription']?['status'],
    trialDaysLeft: j['subscription']?['trialDaysLeft'],
    today: j['today'],
    selectedDate: j['selectedDate'],
    currency: j['currency'],
    week: [for (final w in j['week'] as List) (date: w['date'] as String, count: _i(w['count']))],
    appointments: [for (final a in j['appointments'] as List) Appointment.fromJson(a)],
    dayRevenueMinor: _i(j['dayRevenueMinor']),
    clientsTotal: _i(j['clients']['total']),
    clientsNew: _i(j['clients']['newThisMonth']),
    monthTotalMinor: _i(j['finance']['totalMinor']),
    monthCompletedMinor: _i(j['finance']['completedMinor']),
    monthPlannedMinor: _i(j['finance']['plannedMinor']),
    month: j['finance']['month'],
  );
}

class FreeSlots {
  FreeSlots({required this.name, this.phone, this.locationName, this.address, required this.bookingUrl, required this.days, required this.durationMinutes});
  final String name, bookingUrl;
  final String? phone, locationName, address;
  final int durationMinutes;
  final List<({String date, List<String> times})> days;
  factory FreeSlots.fromJson(Map<String, dynamic> j) => FreeSlots(
    name: j['card']['name'],
    phone: j['card']['phone'],
    locationName: j['card']['locationName'],
    address: j['card']['address'],
    bookingUrl: j['bookingUrl'],
    durationMinutes: _i(j['durationMinutes']),
    days: [for (final d in j['days'] as List) (date: d['date'] as String, times: (d['times'] as List).cast<String>())],
  );
}

class Location {
  Location({required this.id, required this.name, this.address});
  final String id, name;
  final String? address;
  factory Location.fromJson(Map<String, dynamic> j) => Location(id: j['id'], name: j['name'], address: j['address']);
}

class ScheduleDay {
  ScheduleDay({
    required this.weekday,
    required this.startMinute,
    required this.endMinute,
    this.breakStartMinute,
    this.breakEndMinute,
    required this.locationId,
  });
  int weekday, startMinute, endMinute;
  int? breakStartMinute, breakEndMinute;
  String locationId;
  factory ScheduleDay.fromJson(Map<String, dynamic> j) => ScheduleDay(
    weekday: _i(j['weekday']),
    startMinute: _i(j['startMinute']),
    endMinute: _i(j['endMinute']),
    breakStartMinute: j['breakStartMinute'],
    breakEndMinute: j['breakEndMinute'],
    locationId: j['locationId'],
  );
  Map<String, dynamic> toJson() => {
    'weekday': weekday,
    'startMinute': startMinute,
    'endMinute': endMinute,
    if (breakStartMinute != null) 'breakStartMinute': breakStartMinute,
    if (breakEndMinute != null) 'breakEndMinute': breakEndMinute,
    'locationId': locationId,
  };
}

class Business {
  Business({required this.raw});
  final Map<String, dynamic> raw;
  String get id => raw['id'];
  String get name => raw['name'];
  String get slug => raw['slug'];
  String get currency => raw['currency'];
  String get timezone => raw['timezone'];
  bool get onlineBookingEnabled => raw['onlineBookingEnabled'] == true;
  bool get waitlistEnabled => raw['waitlistEnabled'] == true;
  bool get requireApproval => raw['requireApproval'] == true;
  int get minNoticeMinutes => _i(raw['minNoticeMinutes']);
  int get maxHorizonDays => _i(raw['maxHorizonDays']);
  int get slotStepMinutes => _i(raw['slotStepMinutes']);
  List<Location> get locations => [for (final l in raw['locations'] as List? ?? const []) Location.fromJson(l)];
  List<Map<String, dynamic>> get employees => [...(raw['employees'] as List? ?? const []).cast<Map<String, dynamic>>()];
}

class Conversation {
  Conversation({required this.id, required this.title, required this.kind, this.lastMessage, this.lastAt, required this.unread});
  final String id, title, kind;
  final String? lastMessage;
  final DateTime? lastAt;
  final int unread;
  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
    id: j['id'],
    title: j['title'],
    kind: j['kind'],
    lastMessage: j['lastMessage']?['body'],
    lastAt: _dtn(j['lastMessage']?['createdAt']),
    unread: _i(j['unread']),
  );
}

class Message {
  Message({required this.id, required this.body, required this.createdAt, this.senderUserId, this.readAt});
  final String id, body;
  final DateTime createdAt;
  final String? senderUserId;
  final DateTime? readAt;
  factory Message.fromJson(Map<String, dynamic> j) =>
      Message(id: j['id'], body: j['body'], createdAt: _dt(j['createdAt']), senderUserId: j['senderUserId'], readAt: _dtn(j['readAt']));
}

class ClientProfile {
  ClientProfile({
    required this.client,
    required this.visits,
    required this.totalSpentMinor,
    this.lastVisit,
    this.next,
    required this.appointments,
    required this.noShows,
  });
  final Client client;
  final int visits, totalSpentMinor, noShows;
  final DateTime? lastVisit;
  final Appointment? next;
  final List<Appointment> appointments;
  factory ClientProfile.fromJson(Map<String, dynamic> j) => ClientProfile(
    client: Client.fromJson(j['client']),
    visits: _i(j['stats']['visits']),
    totalSpentMinor: _i(j['stats']['totalSpentMinor']),
    noShows: _i(j['stats']['noShows']),
    lastVisit: _dtn(j['stats']['lastVisit']),
    next: j['stats']['nextAppointment'] == null ? null : Appointment.fromJson(j['stats']['nextAppointment']),
    appointments: [for (final a in j['appointments'] as List) Appointment.fromJson(a)],
  );
}
