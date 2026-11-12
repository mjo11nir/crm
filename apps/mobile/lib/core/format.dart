import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

bool _tzReady = false;
tz.Location? _zone;

/// Times are always shown in the business IANA timezone, not the device zone.
void setBusinessZone(String zone) {
  if (!_tzReady) {
    tzdata.initializeTimeZones();
    _tzReady = true;
  }
  try {
    _zone = tz.getLocation(zone);
  } catch (_) {
    _zone = null;
  }
}

DateTime toBusinessLocal(DateTime utc) {
  final z = _zone;
  if (z == null) return utc.toLocal();
  final t = tz.TZDateTime.from(utc, z);
  return DateTime(t.year, t.month, t.day, t.hour, t.minute, t.second);
}

/// Business-local wall clock -> UTC instant.
DateTime fromBusinessLocal(DateTime local) {
  final z = _zone;
  if (z == null) return local.toUtc();
  return tz.TZDateTime(z, local.year, local.month, local.day, local.hour, local.minute).toUtc();
}

/// Overridable clock (tests use a fixed instant for deterministic goldens).
DateTime Function() appNow = DateTime.now;

DateTime businessToday() => dateOnly(toBusinessLocal(appNow().toUtc()));

/// Money is integer minor units end-to-end; formatting is locale-aware.
String formatMoney(int minor, String currency, String locale, {bool compact = false}) {
  final f = NumberFormat.simpleCurrency(locale: locale, name: currency, decimalDigits: compact && minor % 100 == 0 ? 0 : 2);
  return f.format(minor / 100);
}

String hhmm(DateTime utc, [String _ = '']) => DateFormat('HH:mm').format(toBusinessLocal(utc));

String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime startOfWeek(DateTime d) => dateOnly(d).subtract(Duration(days: d.weekday - 1));
