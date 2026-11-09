import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/features/assignments/data/assignment.dart';
import 'package:stark_vms_frontend/features/maintenance/data/maintenance_record.dart';

void main() {
  Map<String, dynamic> recordJson({int id = 1, Object cost = 3500.0}) => {
    'id': id,
    'vehicleId': 12,
    'vehicleNumber': 'DHK-1234',
    'serviceDate': '2026-11-10',
    'maintenanceType': 'OIL_CHANGE',
    'cost': cost,
    'vendorName': 'Navana Service Centre',
    'odometerKm': 45210,
    'notes': 'Synthetic oil',
    'createdAt': '2026-11-10T08:00:00Z',
    'updatedAt': '2026-11-10T08:00:00Z',
    'createdBy': 'staff@stark.local',
  };

  group('MaintenanceHistory.fromJson (FR-M02)', () {
    test('parses page fields plus totalCost and recordCount', () {
      final history = MaintenanceHistory.fromJson({
        'content': [recordJson(), recordJson(id: 2, cost: 9000)],
        'page': 0,
        'size': 10,
        'totalElements': 14,
        'totalPages': 2,
        'totalCost': 12500.0,
        'recordCount': 14,
      });

      expect(history.records, hasLength(2));
      expect(history.page.totalElements, 14);
      expect(history.page.totalPages, 2);
      expect(history.totalCost, 12500.0);
      expect(history.recordCount, 14);
      expect(history.records.last.cost, 9000.0);
    });

    test('missing totals default to 0 / totalElements', () {
      final history = MaintenanceHistory.fromJson({
        'content': <Object>[],
        'page': 0,
        'size': 10,
        'totalElements': 0,
        'totalPages': 0,
      });

      expect(history.totalCost, 0);
      expect(history.recordCount, 0);
      expect(history.records, isEmpty);
    });
  });

  test('MaintenanceRecord parses a response, optional fields may be null', () {
    final record = MaintenanceRecord.fromJson({
      ...recordJson(cost: 3500),
      'vendorName': null,
      'odometerKm': null,
      'notes': null,
    });

    expect(record.serviceDate, DateTime(2026, 11, 10));
    expect(record.maintenanceType, MaintenanceType.oilChange);
    expect(record.cost, 3500.0);
    expect(record.vendorName, isNull);
    expect(record.odometerKm, isNull);
  });

  test('MaintenanceInput trims text and sends blanks as null', () {
    final input = MaintenanceInput(
      serviceDate: DateTime(2026, 11, 10),
      maintenanceType: MaintenanceType.tyre,
      cost: 1200.5,
      vendorName: '  ',
      odometerKm: 100,
      notes: ' front tyres ',
    );

    expect(input.toJson(), {
      'serviceDate': '2026-11-10',
      'maintenanceType': 'TYRE',
      'cost': 1200.5,
      'vendorName': null,
      'odometerKm': 100,
      'notes': 'front tyres',
    });
  });

  group('Assignment.fromJson (FR-DR02)', () {
    test('parses a current assignment', () {
      final assignment = Assignment.fromJson({
        'id': 9,
        'vehicleId': 12,
        'vehicleNumber': 'DHK-1234',
        'driverId': 4,
        'driverName': 'Rahim Uddin',
        'assignedAt': '2026-11-18T04:00:00Z',
        'unassignedAt': null,
        'current': true,
        'assignedBy': 'admin@stark.local',
      });

      expect(assignment.id, 9);
      expect(assignment.vehicleNumber, 'DHK-1234');
      expect(assignment.driverName, 'Rahim Uddin');
      expect(assignment.current, isTrue);
      expect(assignment.unassignedAt, isNull);
      expect(assignment.assignedAt, DateTime.utc(2026, 11, 18, 4));
    });

    test('a closed assignment; `current` falls back to unassignedAt', () {
      final assignment = Assignment.fromJson({
        'id': 8,
        'vehicleId': 12,
        'driverId': 5,
        'assignedAt': '2026-10-01T04:00:00Z',
        'unassignedAt': '2026-11-18T04:00:00Z',
      });

      expect(assignment.current, isFalse);
      expect(assignment.unassignedAt, DateTime.utc(2026, 11, 18, 4));
    });
  });
}
