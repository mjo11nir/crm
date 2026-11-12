import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Tokens {
  Tokens(this.accessToken, this.refreshToken);
  final String accessToken;
  final String refreshToken;
}

abstract class TokenStore {
  Future<Tokens?> read();
  Future<void> write(Tokens t);
  Future<void> clear();
}

/// Keychain / Keystore backed storage for credentials.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? s]) : _s = s ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;
  Tokens? _cache;

  @override
  Future<Tokens?> read() async {
    if (_cache != null) return _cache;
    final a = await _s.read(key: 'access');
    final r = await _s.read(key: 'refresh');
    return _cache = (a != null && r != null) ? Tokens(a, r) : null;
  }

  @override
  Future<void> write(Tokens t) async {
    _cache = t;
    await _s.write(key: 'access', value: t.accessToken);
    await _s.write(key: 'refresh', value: t.refreshToken);
  }

  @override
  Future<void> clear() async {
    _cache = null;
    await _s.delete(key: 'access');
    await _s.delete(key: 'refresh');
  }
}

class MemoryTokenStore implements TokenStore {
  Tokens? t;
  @override
  Future<Tokens?> read() async => t;
  @override
  Future<void> write(Tokens t) async => this.t = t;
  @override
  Future<void> clear() async => t = null;
}
