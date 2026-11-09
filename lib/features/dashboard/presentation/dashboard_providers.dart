import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/change_tracker.dart';
import '../../documents/presentation/document_providers.dart';
import '../../maintenance/presentation/maintenance_providers.dart';
import '../data/dashboard_repository.dart';
import '../data/dashboard_summary.dart';

/// `GET /dashboard/summary` (FR-DB01). Any vehicle, driver, document or
/// maintenance change refreshes it, so the numbers match the database.
final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>((
  ref,
) {
  ref
    ..watch(vehicleChangesProvider)
    ..watch(driverChangesProvider)
    ..watch(documentChangesProvider)
    ..watch(maintenanceChangesProvider);
  return ref.watch(dashboardRepositoryProvider).summary();
});
