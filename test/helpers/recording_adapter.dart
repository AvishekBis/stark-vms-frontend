import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:stark_vms_frontend/core/network/api_client.dart';
import 'package:stark_vms_frontend/core/network/slow_request_monitor.dart';

/// One canned HTTP answer.
class CannedResponse {
  const CannedResponse(this.statusCode, {this.body, this.headers = const {}});

  final int statusCode;

  /// Encoded as JSON; `null` sends an empty body (e.g. 204).
  final Object? body;
  final Map<String, List<String>> headers;
}

/// Answers every request with [respond] and records what was sent, so
/// tests can check paths, methods and JSON bodies of the real repositories.
class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter(this.respond);

  /// Always the same answer.
  factory RecordingAdapter.always(int statusCode, {Object? body}) =>
      RecordingAdapter((_) => CannedResponse(statusCode, body: body));

  final CannedResponse Function(RequestOptions request) respond;
  final List<RequestOptions> requests = [];

  RequestOptions get last => requests.last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final answer = respond(options);
    final body = answer.body;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      answer.statusCode,
      headers: {
        if (body != null)
          Headers.contentTypeHeader: [
            answer.statusCode >= 400
                ? 'application/problem+json'
                : Headers.jsonContentType,
          ],
        ...answer.headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A real [ApiClient] on top of [adapter]; [onUnauthorized] counts 401s.
ApiClient apiClientFor(
  RecordingAdapter adapter, {
  String? token = 'test-token',
  void Function()? onUnauthorized,
}) {
  return ApiClient(
    baseUrl: 'http://api.test/api/v1',
    readAccessToken: () => token,
    onUnauthorized: onUnauthorized ?? () {},
    slowRequestMonitor: SlowRequestMonitor(threshold: Duration.zero),
    dio: Dio()..httpClientAdapter = adapter,
  );
}
