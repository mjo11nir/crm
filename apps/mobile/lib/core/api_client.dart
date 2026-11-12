import 'dart:async';

import 'package:dio/dio.dart';

import 'token_store.dart';

const apiBaseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:3000/api/v1');

/// Typed API error surfaced to the UI.
class ApiException implements Exception {
  ApiException(this.message, {this.status, this.code});
  final String message;
  final int? status;
  final String? code;
  bool get isNetwork => status == null;
  @override
  String toString() => message;

  static ApiException from(Object e) {
    if (e is ApiException) return e;
    if (e is DioException) {
      final data = e.response?.data;
      String msg = 'Network error';
      String? code;
      if (data is Map) {
        final m = data['message'];
        msg = m is List ? m.join('\n') : (m?.toString() ?? msg);
        code = data['code']?.toString();
      }
      return ApiException(msg, status: e.response?.statusCode, code: code);
    }
    return ApiException(e.toString());
  }
}

/// Dio wrapper: injects the access token and transparently rotates it once on 401.
class ApiClient {
  ApiClient(this._tokens, {Dio? dio, this.onSessionExpired})
    : dio = dio ?? Dio(BaseOptions(baseUrl: apiBaseUrl, connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 20))) {
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final t = await _tokens.read();
          if (t != null && options.extra['noAuth'] != true) options.headers['Authorization'] = 'Bearer ${t.accessToken}';
          handler.next(options);
        },
        onError: (err, handler) async {
          final req = err.requestOptions;
          if (err.response?.statusCode == 401 && req.extra['retried'] != true && req.extra['noAuth'] != true) {
            final ok = await _refresh();
            if (ok) {
              req.extra['retried'] = true;
              final t = await _tokens.read();
              req.headers['Authorization'] = 'Bearer ${t!.accessToken}';
              try {
                return handler.resolve(await this.dio.fetch(req));
              } on DioException catch (e) {
                return handler.next(e);
              }
            }
            onSessionExpired?.call();
          }
          handler.next(err);
        },
      ),
    );
  }

  final Dio dio;
  final TokenStore _tokens;
  final void Function()? onSessionExpired;
  Completer<bool>? _refreshing;

  Future<bool> _refresh() async {
    if (_refreshing != null) return _refreshing!.future; // single-flight
    final c = _refreshing = Completer<bool>();
    try {
      final t = await _tokens.read();
      if (t == null) return false;
      final r = await dio.post(
        '/auth/refresh',
        data: {'refreshToken': t.refreshToken},
        options: Options(extra: {'noAuth': true}),
      );
      await _tokens.write(Tokens(r.data['accessToken'], r.data['refreshToken']));
      c.complete(true);
    } catch (_) {
      await _tokens.clear();
      c.complete(false);
    } finally {
      _refreshing = null;
    }
    return c.future;
  }

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) => _wrap(() => dio.get(path, queryParameters: query));
  Future<T> post<T>(String path, {Object? data, Map<String, String>? headers, bool noAuth = false}) => _wrap(
    () => dio.post(
      path,
      data: data,
      options: Options(headers: headers, extra: {'noAuth': noAuth}),
    ),
  );
  Future<T> patch<T>(String path, {Object? data}) => _wrap(() => dio.patch(path, data: data));
  Future<T> put<T>(String path, {Object? data}) => _wrap(() => dio.put(path, data: data));
  Future<T> delete<T>(String path, {Object? data}) => _wrap(() => dio.delete(path, data: data));

  Future<T> _wrap<T>(Future<Response> Function() f) async {
    try {
      final r = await f();
      return r.data as T;
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}
