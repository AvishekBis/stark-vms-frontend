import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/network/page_response.dart';
import '../../../core/network/response_parsing.dart';
import 'vehicle.dart';
import 'vehicle_enums.dart';
import 'vehicle_query.dart';

/// Vehicle endpoints (FR-V01 … FR-V09). All data comes from the API.
abstract interface class VehicleRepository {
  /// Server-side search, status / type filters, sort and pagination.
  Future<PageResponse<Vehicle>> list(VehicleQuery query);

  Future<Vehicle> get(int id);

  Future<Vehicle> create(VehicleInput input);

  /// `PUT /vehicles/{id}` with the [version] the form was loaded with;
  /// 409 `stale-version` when someone else changed it meanwhile.
  Future<Vehicle> update(int id, VehicleInput input, {required int version});

  /// ADMIN only; the server answers 403 for STAFF and 409
  /// `vehicle-has-history` when the vehicle has history (BR-10).
  Future<void> delete(int id);

  /// `PATCH /vehicles/{id}/status` — ADMIN only (FR-V07). INACTIVE also
  /// closes the current driver assignment on the server.
  Future<Vehicle> changeStatus(int id, VehicleStatus status);
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
    return ResponseParsing.parse(
      () =>
          PageResponse.fromJson(ResponseParsing.object(body), Vehicle.fromJson),
    );
  }

  @override
  Future<Vehicle> get(int id) async {
    final body = await _client.get('$_basePath/$id');
    return _vehicle(body);
  }

  @override
  Future<Vehicle> create(VehicleInput input) async {
    final body = await _client.post(_basePath, body: input.toJson());
    return _vehicle(body);
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
    return _vehicle(body);
  }

  @override
  Future<void> delete(int id) => _client.delete('$_basePath/$id');

  @override
  Future<Vehicle> changeStatus(int id, VehicleStatus status) async {
    final body = await _client.patch(
      '$_basePath/$id/status',
      body: {'status': status.apiValue},
    );
    return _vehicle(body);
  }

  static Vehicle _vehicle(Object? body) => ResponseParsing.parse(
    () => Vehicle.fromJson(ResponseParsing.object(body)),
  );
}

final vehicleRepositoryProvider = Provider<VehicleRepository>(
  (ref) => ApiVehicleRepository(ref.watch(apiClientProvider)),
);
