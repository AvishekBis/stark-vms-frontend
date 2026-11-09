import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/network/api_client.dart';
import 'package:stark_vms_frontend/core/network/api_exception.dart';
import 'package:stark_vms_frontend/core/network/slow_request_monitor.dart';

/// Answers every request with [statusCode] and [body], recording the request.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({required this.statusCode, required this.body});

  final int statusCode;
  final Map<String, Object?> body;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/problem+json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late int unauthorizedCalls;

  ApiClient clientWith(_RecordingAdapter adapter, {String? token}) {
    unauthorizedCalls = 0;
    return ApiClient(
      baseUrl: 'http://api.test/api/v1',
      readAccessToken: () => token,
      onUnauthorized: () => unauthorizedCalls++,
      slowRequestMonitor: SlowRequestMonitor(threshold: Duration.zero),
      dio: Dio()..httpClientAdapter = adapter,
    );
  }

  group('ApiClient (guideline 14.2: one client adds the JWT)', () {
    test('adds the bearer token and sends query parameters', () async {
      final adapter = _RecordingAdapter(
        statusCode: 200,
        body: {'content': <Object?>[]},
      );
      final client = clientWith(adapter, token: 'abc');

      await client.get(
        '/vehicles',
        queryParameters: {'page': 2, 'size': 20, 'sort': 'createdAt,desc'},
      );

      final request = adapter.requests.single;
      expect(request.headers['Authorization'], 'Bearer abc');
      expect(request.uri.path, '/api/v1/vehicles');
      expect(request.uri.queryParameters, {
        'page': '2',
        'size': '20',
        'sort': 'createdAt,desc',
      });
    });

    test('sends no Authorization header without a token', () async {
      final adapter = _RecordingAdapter(statusCode: 200, body: {});
      final client = clientWith(adapter);

      await client.get('/auth/me');

      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('a 401 on a protected call signs the user out (FR-AUTH-02)', () async {
      final adapter = _RecordingAdapter(
        statusCode: 401,
        body: {'status': 401, 'detail': 'Token expired.'},
      );
      final client = clientWith(adapter, token: 'expired');

      await expectLater(
        client.get('/vehicles'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
      expect(unauthorizedCalls, 1);
    });

    test('a 401 from login is a wrong password, not an expiry', () async {
      final adapter = _RecordingAdapter(
        statusCode: 401,
        body: {'status': 401, 'detail': 'Invalid email or password.'},
      );
      final client = clientWith(adapter, token: 'old');

      await expectLater(
        client.post('/auth/login', body: {'email': 'a@b.c', 'password': 'x'}),
        throwsA(isA<ApiException>()),
      );
      expect(unauthorizedCalls, 0);
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('a 403 does not sign the user out (TC-07)', () async {
      final adapter = _RecordingAdapter(
        statusCode: 403,
        body: {'status': 403, 'detail': 'Forbidden.'},
      );
      final client = clientWith(adapter, token: 'staff');

      await expectLater(
        client.delete('/vehicles/1'),
        throwsA(isA<ApiException>().having((e) => e.isForbidden, '403', true)),
      );
      expect(unauthorizedCalls, 0);
    });
  });
}
