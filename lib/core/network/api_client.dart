import 'dart:async';

import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'slow_request_monitor.dart';

/// Supplies the current access token, or `null` when nobody is logged in.
typedef AccessTokenReader = String? Function();

/// The single HTTP client of the app (guideline 14.2).
///
/// * adds `Authorization: Bearer <token>` to every request,
/// * reports a 401 on any request except login through [onUnauthorized],
/// * turns every failure into an [ApiException],
/// * reports slow requests to the [SlowRequestMonitor].
class ApiClient {
  ApiClient({
    required String baseUrl,
    required AccessTokenReader readAccessToken,
    required void Function() onUnauthorized,
    required this._slowRequestMonitor,
    Duration timeout = const Duration(seconds: 75),
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = baseUrl
      ..connectTimeout = timeout
      ..receiveTimeout = timeout
      ..contentType = Headers.jsonContentType
      ..responseType = ResponseType.json
      ..headers[Headers.acceptHeader] =
          'application/json, application/problem+json';
    _dio.interceptors.add(
      AuthInterceptor(
        readAccessToken: readAccessToken,
        onUnauthorized: onUnauthorized,
      ),
    );
  }

  final Dio _dio;
  final SlowRequestMonitor _slowRequestMonitor;

  Future<Object?> get(String path, {Map<String, Object?>? queryParameters}) {
    return _send(
      () => _dio.get<Object?>(path, queryParameters: queryParameters),
    );
  }

  Future<Object?> post(String path, {Object? body}) {
    return _send(() => _dio.post<Object?>(path, data: body));
  }

  Future<Object?> put(String path, {Object? body}) {
    return _send(() => _dio.put<Object?>(path, data: body));
  }

  Future<void> delete(String path) async {
    await _send(() => _dio.delete<Object?>(path));
  }

  Future<Object?> _send(Future<Response<Object?>> Function() request) async {
    try {
      final response = await _slowRequestMonitor.track(request);
      return response.data;
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }
}

/// Adds the bearer token and reacts to expired / invalid sessions.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.readAccessToken,
    required this.onUnauthorized,
  });

  static const String loginPath = '/auth/login';

  final AccessTokenReader readAccessToken;
  final void Function() onUnauthorized;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = readAccessToken();
    if (token != null && !_isLoginRequest(options)) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401 &&
        !_isLoginRequest(err.requestOptions)) {
      onUnauthorized();
    }
    handler.next(err);
  }

  bool _isLoginRequest(RequestOptions options) {
    return options.path.endsWith(loginPath);
  }
}
