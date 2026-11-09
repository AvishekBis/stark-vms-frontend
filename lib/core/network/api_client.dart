import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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

  Future<Object?> patch(String path, {Object? body}) {
    return _send(() => _dio.patch<Object?>(path, data: body));
  }

  Future<void> delete(String path) async {
    await _send(() => _dio.delete<Object?>(path));
  }

  /// Sends `multipart/form-data` (file uploads). Dio sets the boundary and
  /// the content type for [FormData] itself.
  Future<Object?> postMultipart(String path, FormData data) {
    return _send(() => _dio.post<Object?>(path, data: data));
  }

  /// Downloads raw bytes (e.g. a stored document) with the bearer token.
  ///
  /// Error bodies arrive as bytes too, so they are decoded back into a
  /// Problem Details [ApiException].
  Future<BinaryResponse> getBytes(
    String path, {
    Map<String, Object?>? queryParameters,
  }) async {
    try {
      final response = await _slowRequestMonitor.track(
        () => _dio.get<List<int>>(
          path,
          queryParameters: queryParameters,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {Headers.acceptHeader: '*/*'},
          ),
        ),
      );
      return BinaryResponse(
        bytes: Uint8List.fromList(response.data ?? const <int>[]),
        contentType: response.headers.value(Headers.contentTypeHeader),
        fileName: BinaryResponse.fileNameFromDisposition(
          response.headers.value('content-disposition'),
        ),
      );
    } on DioException catch (error) {
      final response = error.response;
      final data = response?.data;
      if (data is List<int>) {
        throw ApiException.fromProblemDetails(
          _decodeJsonBytes(data),
          statusCode: response?.statusCode,
        );
      }
      throw ApiException.fromDioException(error);
    }
  }

  static Object? _decodeJsonBytes(List<int> bytes) {
    try {
      return jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return null;
    }
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

/// A downloaded file: bytes plus what the server said about them.
class BinaryResponse {
  const BinaryResponse({required this.bytes, this.contentType, this.fileName});

  final Uint8List bytes;
  final String? contentType;

  /// From `Content-Disposition: inline; filename="..."`, when exposed.
  final String? fileName;

  static final RegExp _quotedName = RegExp(r'filename="([^"]*)"');
  static final RegExp _plainName = RegExp(r'filename=([^;]+)');

  static String? fileNameFromDisposition(String? header) {
    if (header == null) {
      return null;
    }
    final match =
        _quotedName.firstMatch(header) ?? _plainName.firstMatch(header);
    final name = match?.group(1)?.trim();
    return name == null || name.isEmpty ? null : name;
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
