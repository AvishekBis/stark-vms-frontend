import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/network/response_parsing.dart';
import 'maintenance_record.dart';

/// Maintenance endpoints (FR-M01, FR-M02).
abstract interface class MaintenanceRepository {
  /// Newest service date first, with `totalCost` and `recordCount`.
  Future<MaintenanceHistory> history(
    int vehicleId, {
    int page = 0,
    int size = defaultPageSize,
  });

  Future<MaintenanceRecord> create(int vehicleId, MaintenanceInput input);

  Future<MaintenanceRecord> get(int recordId);

  /// Sends the loaded [version]; 409 `stale-version` when it is outdated.
  Future<MaintenanceRecord> update(
    int recordId,
    MaintenanceInput input, {
    required int version,
  });

  /// ADMIN only.
  Future<void> delete(int recordId);

  static const int defaultPageSize = 10;
}

class ApiMaintenanceRepository implements MaintenanceRepository {
  const ApiMaintenanceRepository(this._client);

  final ApiClient _client;

  @override
  Future<MaintenanceHistory> history(
    int vehicleId, {
    int page = 0,
    int size = MaintenanceRepository.defaultPageSize,
  }) async {
    final body = await _client.get(
      '/vehicles/$vehicleId/maintenance',
      queryParameters: {'page': page, 'size': size},
    );
    return ResponseParsing.parse(
      () => MaintenanceHistory.fromJson(ResponseParsing.object(body)),
    );
  }

  @override
  Future<MaintenanceRecord> create(
    int vehicleId,
    MaintenanceInput input,
  ) async => _record(
    await _client.post(
      '/vehicles/$vehicleId/maintenance',
      body: input.toJson(),
    ),
  );

  @override
  Future<MaintenanceRecord> get(int recordId) async =>
      _record(await _client.get('/maintenance/$recordId'));

  @override
  Future<MaintenanceRecord> update(
    int recordId,
    MaintenanceInput input, {
    required int version,
  }) async => _record(
    await _client.put(
      '/maintenance/$recordId',
      body: input.toUpdateJson(version),
    ),
  );

  @override
  Future<void> delete(int recordId) => _client.delete('/maintenance/$recordId');

  static MaintenanceRecord _record(Object? body) => ResponseParsing.parse(
    () => MaintenanceRecord.fromJson(ResponseParsing.object(body)),
  );
}

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>(
  (ref) => ApiMaintenanceRepository(ref.watch(apiClientProvider)),
);
