import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/page_response.dart';
import '../../../core/utils/change_tracker.dart';
import '../../drivers/data/driver.dart';
import '../../drivers/data/driver_query.dart';
import '../../drivers/data/driver_repository.dart';
import '../../vehicles/presentation/vehicle_providers.dart';
import '../data/assignment.dart';
import '../data/assignment_repository.dart';

/// One page of a vehicle's driver history (newest first).
final vehicleAssignmentsProvider = FutureProvider.autoDispose
    .family<PageResponse<Assignment>, ({int vehicleId, int page})>((ref, key) {
      ref
        ..watch(vehicleChangesProvider)
        ..watch(driverChangesProvider);
      return ref
          .watch(assignmentRepositoryProvider)
          .vehicleHistory(key.vehicleId, page: key.page);
    });

/// One page of a driver's vehicle history (newest first).
final driverAssignmentsProvider = FutureProvider.autoDispose
    .family<PageResponse<Assignment>, ({int driverId, int page})>((ref, key) {
      ref
        ..watch(vehicleChangesProvider)
        ..watch(driverChangesProvider);
      return ref
          .watch(assignmentRepositoryProvider)
          .driverHistory(key.driverId, page: key.page);
    });

/// Drivers offered in the assign dialog (`GET /drivers?available=true…`).
final assignableDriversProvider = FutureProvider.autoDispose
    .family<PageResponse<Driver>, DriverQuery>((ref, query) {
      return ref.watch(driverRepositoryProvider).list(query);
    });

/// Assign / unassign (FR-DR02). Both refresh vehicles, drivers, histories
/// and the dashboard.
class AssignmentActions {
  const AssignmentActions(this._ref);

  final Ref<Object?> _ref;

  Future<Assignment> assign({
    required int vehicleId,
    required int driverId,
  }) async {
    final assignment = await _ref
        .read(assignmentRepositoryProvider)
        .assign(vehicleId: vehicleId, driverId: driverId);
    _changed(vehicleId);
    return assignment;
  }

  Future<void> unassign(int vehicleId) async {
    await _ref.read(assignmentRepositoryProvider).unassign(vehicleId);
    _changed(vehicleId);
  }

  void _changed(int vehicleId) {
    _ref.read(vehicleChangesProvider.notifier).markChanged();
    _ref.read(driverChangesProvider.notifier).markChanged();
    _ref.invalidate(vehicleDetailProvider(vehicleId));
  }
}

final assignmentActionsProvider = Provider<AssignmentActions>(
  (ref) => AssignmentActions(ref),
);
