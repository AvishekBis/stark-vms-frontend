import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/network/page_response.dart';
import 'vehicle.dart';
import 'vehicle_query.dart';

/// Vehicle endpoints (FR-V01 … FR-V06). All data comes from the API.
abstract interface class VehicleRepository {
  Future<PageResponse<Vehicle>> list(VehicleQuery query);

  Future<Vehicle> get(int id);

  Future<Vehicle> create(VehicleInput input);

  /// `PUT /vehicles/{id}` with the [version] the form was loaded with;
  /// 409 `stale-version` when someone else changed it meanwhile.
  Future<Vehicle> update(int id, VehicleInput input, {required int version});

  /// ADMIN only; the server answers 403 for STAFF.
  Future<void> delete(int id);
}

class ApiVehicleRepository implements VehicleRepository {
  const ApiVehicleRepository(this._client);

  static const String _basePath = '/vehicles';

  final ApiClient _client;

  @override
  Future<PageResponse<Vehicle>> list(VehicleQuery query) async {
    final body = await _client.get(
      _basePath,
      queryParameters: query.toQueryParameters(),
    );
    return _parse(
      () => PageResponse.fromJson(_asJsonObject(body), Vehicle.fromJson),
    );
  }

  @override
  Future<Vehicle> get(int id) async {
    final body = await _client.get('$_basePath/$id');
    return _parse(() => Vehicle.fromJson(_asJsonObject(body)));
  }

  @override
  Future<Vehicle> create(VehicleInput input) async {
    final body = await _client.post(_basePath, body: input.toJson());
    return _parse(() => Vehicle.fromJson(_asJsonObject(body)));
  }

  @override
  Future<Vehicle> update(
    int id,
    VehicleInput input, {
    required int version,
  }) async {
    final body = await _client.put(
      '$_basePath/$id',
      body: input.toUpdateJson(version),
    );
    return _parse(() => Vehicle.fromJson(_asJsonObject(body)));
  }

  @override
  Future<void> delete(int id) => _client.delete('$_basePath/$id');

  static Map<String, dynamic> _asJsonObject(Object? body) {
    if (body is Map<String, dynamic>) {
      return body;
    }
    throw const FormatException('Expected a JSON object.');
  }

  static const ApiException _unexpectedData = ApiException(
    kind: ApiErrorKind.unknown,
    message: 'The server sent data this app does not understand.',
  );

  static T _parse<T>(T Function() parse) {
    try {
      return parse();
    } on FormatException {
      throw _unexpectedData;
    } on TypeError {
      throw _unexpectedData;
    }
  }
}

final vehicleRepositoryProvider = Provider<VehicleRepository>(
  (ref) => ApiVehicleRepository(ref.watch(apiClientProvider)),
);
