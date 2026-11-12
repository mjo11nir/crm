import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Read-through offline cache for core read workflows (calendar, clients, services, settings).
/// Writes are never applied optimistically offline: the UI only shows a booking as confirmed
/// after the server accepted it (see docs/offline.md).
class OfflineCache {
  OfflineCache(this._prefs);
  final SharedPreferences? _prefs;

  Future<void> put(String key, Object? json) async => _prefs?.setString('cache:$key', jsonEncode({'at': DateTime.now().toIso8601String(), 'v': json}));

  ({Object? value, DateTime at})? get(String key) {
    final raw = _prefs?.getString('cache:$key');
    if (raw == null) return null;
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return (value: m['v'], at: DateTime.parse(m['at'] as String));
  }
}
