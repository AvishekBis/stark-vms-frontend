import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../vehicles/data/vehicle.dart';
import '../../vehicles/data/vehicle_query.dart';
import '../../vehicles/data/vehicle_repository.dart';
import '../../vehicles/presentation/vehicle_providers.dart';

/// v1.0 dashboard data, derived from the vehicle list endpoint.
/// v2.0 replaces these with one `GET /dashboard/summary` call (FR-DB01).
abstract final class DashboardQueries {
  /// Only `totalElements` is needed, so ask for a single row.
  static const VehicleQuery totalVehicles = VehicleQuery(size: 1);

  static const int recentCount = 5;
  static const VehicleQuery recentVehicles = VehicleQuery(
    size: recentCount,
    sortField: VehicleSortField.createdAt,
    sortDirection: SortDirection.descending,
  );
}

final totalVehiclesProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(vehicleChangesProvider);
  final page = await ref
      .watch(vehicleRepositoryProvider)
      .list(DashboardQueries.totalVehicles);
  return page.totalElements;
});

final recentVehiclesProvider = FutureProvider.autoDispose<List<Vehicle>>((
  ref,
) async {
  ref.watch(vehicleChangesProvider);
  final page = await ref
      .watch(vehicleRepositoryProvider)
      .list(DashboardQueries.recentVehicles);
  return page.content;
});
