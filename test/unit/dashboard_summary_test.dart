import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/features/dashboard/data/dashboard_summary.dart';
import 'package:stark_vms_frontend/shared/models/expiry_status.dart';

import '../helpers/fakes_v2.dart';

void main() {
  test('parses the full summary (FR-DB01, FR-X02)', () {
    final summary = DashboardSummary.fromJson(dashboardJson());

    expect(summary.vehicles.total, 26);
    expect(summary.vehicles.active, 18);
    expect(summary.vehicles.inactive, 3);
    expect(summary.vehicles.maintenance, 5);
    expect(summary.documents.expired, 2);
    expect(summary.documents.expiringSoon, 4);
    expect(summary.documents.withinDays, 30);
    expect(summary.maintenance.month, '2026-11');
    expect(summary.maintenance.count, 7);
    expect(summary.maintenance.totalCost, 48250.0);
    expect(summary.drivers.total, 12);
    expect(summary.drivers.assigned, 9);
    expect(summary.drivers.licensesExpired, 1);
    expect(summary.drivers.licensesExpiringSoon, 2);
    expect(
      summary.expiringDocuments.single.expiryStatus,
      ExpiryStatus.expiringSoon,
    );
    expect(summary.expiringLicenses.single.licenseStatus, ExpiryStatus.expired);
    expect(summary.generatedAt, DateTime.utc(2026, 11, 18, 4));
  });

  test('empty lists and missing sections become zeros', () {
    final summary = DashboardSummary.fromJson({
      'vehicles': {'total': 0, 'active': 0, 'inactive': 0, 'maintenance': 0},
      'documents': null,
      'maintenance': {'month': '2026-11', 'count': 0, 'totalCost': null},
      'expiringDocuments': <Object>[],
      'expiringLicenses': null,
    });

    expect(summary.vehicles.total, 0);
    expect(summary.documents.expired, 0);
    expect(summary.documents.withinDays, 30);
    expect(summary.maintenance.totalCost, 0);
    expect(summary.drivers.total, 0);
    expect(summary.expiringDocuments, isEmpty);
    expect(summary.expiringLicenses, isEmpty);
    expect(summary.generatedAt, isNull);
  });

  test('integer costs are read as doubles', () {
    final summary = DashboardSummary.fromJson({
      'maintenance': {'count': 1, 'totalCost': 3500},
    });

    expect(summary.maintenance.totalCost, 3500.0);
  });
}
