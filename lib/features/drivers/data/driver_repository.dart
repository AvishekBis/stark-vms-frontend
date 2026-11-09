import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/network/page_response.dart';
import '../../../core/network/response_parsing.dart';
import 'driver.dart';
import 'driver_query.dart';

/// Driver endpoints (FR-DR01).
abstract interface class DriverRepository {
  Future<PageResponse<Driver>> list(DriverQuery query);

  Future<Driver> get(int id);

  /// 409 `duplicate-driver-phone` / `duplicate-driver-license` on duplicates.
  Future<Driver> create(DriverInput input);

  /// Sends the loaded [version]; 409 `stale-version` when it is outdated.
  Future<Driver> update(int id, DriverInput input, {required int version});

  /// ADMIN only; 409 `driver-has-history` when the driver has assignments.
  Future<void> delete(int id);
}

class ApiDriverRepository implements DriverRepository {
  const ApiDriverRepository(this._client);

  static const String _basePath = '/drivers';

  final ApiClient _client;

  @override
  Future<PageResponse<Driver>> list(DriverQuery query) async {
    final body = await _client.get(
      _basePath,
      queryParameters: query.toQueryParameters(),
    );
    return ResponseParsing.parse(
      () =>
          PageResponse.fromJson(ResponseParsing.object(body), Driver.fromJson),
    );
  }

  @override
  Future<Driver> get(int id) async =>
      _driver(await _client.get('$_basePath/$id'));

  @override
  Future<Driver> create(DriverInput input) async =>
      _driver(await _client.post(_basePath, body: input.toJson()));

  @override
  Future<Driver> update(
    int id,
    DriverInput input, {
    required int version,
  }) async => _driver(
    await _client.put('$_basePath/$id', body: input.toUpdateJson(version)),
  );

  @override
  Future<void> delete(int id) => _client.delete('$_basePath/$id');

  static Driver _driver(Object? body) => ResponseParsing.parse(
    () => Driver.fromJson(ResponseParsing.object(body)),
  );
}

final driverRepositoryProvider = Provider<DriverRepository>(
  (ref) => ApiDriverRepository(ref.watch(apiClientProvider)),
);
