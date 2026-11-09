import '../../../core/utils/json_readers.dart';
import '../../documents/data/vehicle_document.dart';
import '../../drivers/data/driver.dart';

/// `GET /dashboard/summary` (FR-DB01, FR-X02). Missing numbers count as 0,
/// missing lists as empty, so a partial response never breaks the page.
class DashboardSummary {
  const DashboardSummary({
    required this.vehicles,
    required this.documents,
    required this.maintenance,
    required this.drivers,
    required this.expiringDocuments,
    required this.expiringLicenses,
    this.generatedAt,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      vehicles: VehicleCounts.fromJson(
        JsonReaders.objectOrEmpty(json['vehicles']),
      ),
      documents: DocumentCounts.fromJson(
        JsonReaders.objectOrEmpty(json['documents']),
      ),
      maintenance: MaintenanceMonth.fromJson(
        JsonReaders.objectOrEmpty(json['maintenance']),
      ),
      drivers: DriverCounts.fromJson(
        JsonReaders.objectOrEmpty(json['drivers']),
      ),
      expiringDocuments: List.unmodifiable(
        JsonReaders.objectList(json['expiringDocuments'])
            .map(VehicleDocument.fromJson),
      ),
      expiringLicenses: List.unmodifiable(
        JsonReaders.objectList(json['expiringLicenses']).map(Driver.fromJson),
      ),
      generatedAt: JsonReaders.timestamp(json['generatedAt']),
    );
  }

  final VehicleCounts vehicles;
  final DocumentCounts documents;
  final MaintenanceMonth maintenance;
  final DriverCounts drivers;
  final List<VehicleDocument> expiringDocuments;
  final List<Driver> expiringLicenses;
  final DateTime? generatedAt;
}

class VehicleCounts {
  const VehicleCounts({
    required this.total,
    required this.active,
    required this.inactive,
    required this.maintenance,
  });

  factory VehicleCounts.fromJson(Map<String, dynamic> json) => VehicleCounts(
    total: JsonReaders.intOr(json['total'], 0),
    active: JsonReaders.intOr(json['active'], 0),
    inactive: JsonReaders.intOr(json['inactive'], 0),
    maintenance: JsonReaders.intOr(json['maintenance'], 0),
  );

  final int total;
  final int active;
  final int inactive;
  final int maintenance;
}

class DocumentCounts {
  const DocumentCounts({
    required this.expired,
    required this.expiringSoon,
    required this.withinDays,
  });

  factory DocumentCounts.fromJson(Map<String, dynamic> json) => DocumentCounts(
    expired: JsonReaders.intOr(json['expired'], 0),
    expiringSoon: JsonReaders.intOr(json['expiringSoon'], 0),
    withinDays: JsonReaders.intOr(json['withinDays'], 30),
  );

  final int expired;
  final int expiringSoon;
  final int withinDays;
}

class MaintenanceMonth {
  const MaintenanceMonth({
    required this.count,
    required this.totalCost,
    this.month,
  });

  factory MaintenanceMonth.fromJson(Map<String, dynamic> json) =>
      MaintenanceMonth(
        month: json['month'] as String?,
        count: JsonReaders.intOr(json['count'], 0),
        totalCost: JsonReaders.doubleOr(json['totalCost'], 0),
      );

  /// `2026-11`.
  final String? month;
  final int count;
  final double totalCost;
}

class DriverCounts {
  const DriverCounts({
    required this.total,
    required this.active,
    required this.assigned,
    required this.licensesExpired,
    required this.licensesExpiringSoon,
  });

  factory DriverCounts.fromJson(Map<String, dynamic> json) => DriverCounts(
    total: JsonReaders.intOr(json['total'], 0),
    active: JsonReaders.intOr(json['active'], 0),
    assigned: JsonReaders.intOr(json['assigned'], 0),
    licensesExpired: JsonReaders.intOr(json['licensesExpired'], 0),
    licensesExpiringSoon: JsonReaders.intOr(json['licensesExpiringSoon'], 0),
  );

  final int total;
  final int active;
  final int assigned;
  final int licensesExpired;
  final int licensesExpiringSoon;
}
