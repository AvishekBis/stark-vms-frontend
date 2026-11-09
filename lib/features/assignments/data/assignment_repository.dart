import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/network/page_response.dart';
import '../../../core/network/response_parsing.dart';
import 'assignment.dart';

/// Driver–vehicle assignment endpoints (FR-DR02, BR-05, BR-06).
abstract interface class AssignmentRepository {
  /// `PUT /vehicles/{id}/driver`. 409 `driver-already-assigned` (TC-10) or
  /// `assignment-not-allowed` when a rule is broken.
  Future<Assignment> assign({required int vehicleId, required int driverId});

  /// `DELETE /vehicles/{id}/driver`. 409 `no-current-driver` when none.
  Future<void> unassign(int vehicleId);

  /// Newest first.
  Future<PageResponse<Assignment>> vehicleHistory(
    int vehicleId, {
    int page = 0,
    int size = defaultPageSize,
  });

  Future<PageResponse<Assignment>> driverHistory(
    int driverId, {
    int page = 0,
    int size = defaultPageSize,
  });

  static const int defaultPageSize = 10;
}

class ApiAssignmentRepository implements AssignmentRepository {
  const ApiAssignmentRepository(this._client);

  final ApiClient _client;

  @override
  Future<Assignment> assign({
    required int vehicleId,
    required int driverId,
  }) async {
    final body = await _client.put(
      '/vehicles/$vehicleId/driver',
      body: {'driverId': driverId},
    );
    return ResponseParsing.parse(
      () => Assignment.fromJson(ResponseParsing.object(body)),
    );
  }

  @override
  Future<void> unassign(int vehicleId) =>
      _client.delete('/vehicles/$vehicleId/driver');

  @override
  Future<PageResponse<Assignment>> vehicleHistory(
    int vehicleId, {
    int page = 0,
    int size = AssignmentRepository.defaultPageSize,
  }) => _history('/vehicles/$vehicleId/assignments', page, size);

  @override
  Future<PageResponse<Assignment>> driverHistory(
    int driverId, {
    int page = 0,
    int size = AssignmentRepository.defaultPageSize,
  }) => _history('/drivers/$driverId/assignments', page, size);

  Future<PageResponse<Assignment>> _history(
    String path,
    int page,
    int size,
  ) async {
    final body = await _client.get(
      path,
      queryParameters: {'page': page, 'size': size},
    );
    return ResponseParsing.parse(
      () => PageResponse.fromJson(
        ResponseParsing.object(body),
        Assignment.fromJson,
      ),
    );
  }
}

final assignmentRepositoryProvider = Provider<AssignmentRepository>(
  (ref) => ApiAssignmentRepository(ref.watch(apiClientProvider)),
);
