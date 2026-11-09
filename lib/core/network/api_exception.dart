import 'package:dio/dio.dart';

/// What kind of failure an [ApiException] represents.
enum ApiErrorKind {
  /// The server answered with an error status (4xx / 5xx).
  http,

  /// The request timed out (for example a cold-starting server).
  timeout,

  /// The server could not be reached at all (offline, CORS, DNS …).
  network,

  /// The request was cancelled by the app.
  cancelled,

  /// The response could not be understood.
  unknown,
}

/// A failed API call, built from an RFC 9457 Problem Details body when the
/// server sent one.
class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.title,
    this.type,
    this.fieldErrors = const {},
  });

  /// Parses a Problem Details body:
  /// `{type, title, status, detail, instance, errors: [{field, message}]}`.
  factory ApiException.fromProblemDetails(Object? body, {int? statusCode}) {
    final json = body is Map<String, dynamic>
        ? body
        : const <String, dynamic>{};
    final status = _asInt(json['status']) ?? statusCode;
    final title = _asNonBlankString(json['title']);
    final detail = _asNonBlankString(json['detail']);
    return ApiException(
      kind: ApiErrorKind.http,
      statusCode: status,
      title: title,
      type: _asNonBlankString(json['type']),
      message: detail ?? title ?? defaultMessageForStatus(status),
      fieldErrors: _parseFieldErrors(json['errors']),
    );
  }

  /// Maps any Dio failure to a user-friendly [ApiException].
  factory ApiException.fromDioException(DioException error) {
    final inner = error.error;
    if (inner is ApiException) {
      return inner;
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          kind: ApiErrorKind.timeout,
          message:
              'The server is taking too long to respond. It may be waking up '
              '- please try again in a moment.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          kind: ApiErrorKind.network,
          message:
              'Cannot reach the server. Check your internet connection and '
              'try again.',
        );
      case DioExceptionType.cancel:
        return const ApiException(
          kind: ApiErrorKind.cancelled,
          message: 'The request was cancelled.',
        );
      case DioExceptionType.badResponse:
        final response = error.response;
        return ApiException.fromProblemDetails(
          response?.data,
          statusCode: response?.statusCode,
        );
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        if (error.response != null) {
          return ApiException.fromProblemDetails(
            error.response?.data,
            statusCode: error.response?.statusCode,
          );
        }
        return const ApiException(
          kind: ApiErrorKind.network,
          message:
              'Cannot reach the server. Check your internet connection and '
              'try again.',
        );
    }
  }

  final ApiErrorKind kind;

  /// Human readable message, safe to show in the UI.
  final String message;
  final int? statusCode;
  final String? title;
  final String? type;

  /// Field name → message, from the Problem Details `errors` array.
  final Map<String, String> fieldErrors;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isValidation => statusCode == 400;

  /// v2.1: 429 from `POST /auth/login` when the e-mail or IP is throttled
  /// (contract 7.1), and from `PUT /auth/me/password` after too many wrong
  /// current passwords (contract 7.3.4). Never a reason to end the session.
  bool get isTooManyRequests => statusCode == 429;

  /// v2.1: 409 `stale-version` - the record changed since it was loaded
  /// (contract 7.2.3).
  bool get isStaleVersion => isConflict && hasType(staleVersionType);

  /// `true` when the Problem Details `type` ends with [suffix]
  /// (e.g. `duplicate-email`).
  bool hasType(String suffix) => type?.endsWith('/errors/$suffix') ?? false;

  static const String staleVersionType = 'stale-version';

  static String defaultMessageForStatus(int? status) {
    return switch (status) {
      400 => 'Some of the data is not valid. Please check the form.',
      401 => 'Your session has expired. Please log in again.',
      403 => 'You do not have permission to perform this action.',
      404 => 'The requested record was not found.',
      409 => 'This change conflicts with existing data.',
      413 => 'The uploaded file is too large.',
      429 => 'Too many failed login attempts. Please try again later.',
      final int code when code >= 500 =>
        'Something went wrong on the server. Please try again.',
      _ => 'Something went wrong. Please try again.',
    };
  }

  static Map<String, String> _parseFieldErrors(Object? raw) {
    if (raw is! List) {
      return const {};
    }
    final errors = <String, String>{};
    for (final entry in raw) {
      if (entry is! Map) {
        continue;
      }
      final field = _asNonBlankString(entry['field']);
      final message = _asNonBlankString(entry['message']);
      if (field != null && message != null) {
        errors.putIfAbsent(field, () => message);
      }
    }
    return Map.unmodifiable(errors);
  }

  static String? _asNonBlankString(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  @override
  String toString() => 'ApiException($statusCode, $kind): $message';
}
