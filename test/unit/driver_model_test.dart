import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/features/drivers/data/driver.dart';
import 'package:stark_vms_frontend/features/drivers/data/driver_query.dart';
import 'package:stark_vms_frontend/shared/models/expiry_status.dart';

void main() {
  Map<String, dynamic> driverJson() => {
    'id': 4,
    'fullName': 'Rahim Uddin',
    'phone': '01711000001',
    'licenseNumber': 'DK0123456L00001',
    'licenseExpiry': '2027-03-31',
    'licenseStatus': 'VALID',
    'daysUntilLicenseExpiry': 147,
    'status': 'ACTIVE',
    'currentVehicle': {'id': 12, 'vehicleNumber': 'DHK-1234'},
    'createdAt': '2026-11-06T09:15:00Z',
    'updatedAt': '2026-11-06T09:15:00Z',
    'createdBy': 'admin@stark.local',
  };

  group('Driver.fromJson', () {
    test('parses a full DriverResponse', () {
      final driver = Driver.fromJson(driverJson());

      expect(driver.id, 4);
      expect(driver.fullName, 'Rahim Uddin');
      expect(driver.licenseExpiry, DateTime(2027, 3, 31));
      expect(driver.licenseStatus, ExpiryStatus.valid);
      expect(driver.daysUntilLicenseExpiry, 147);
      expect(driver.status, DriverStatus.active);
      expect(driver.currentVehicle?.id, 12);
      expect(driver.currentVehicle?.vehicleNumber, 'DHK-1234');
      expect(driver.createdBy, 'admin@stark.local');
      expect(driver.createdAt, DateTime.utc(2026, 11, 6, 9, 15));
    });

    test('currentVehicle null and INACTIVE status', () {
      final driver = Driver.fromJson({
        ...driverJson(),
        'currentVehicle': null,
        'status': 'INACTIVE',
        'licenseStatus': 'EXPIRED',
        'daysUntilLicenseExpiry': -3,
      });

      expect(driver.currentVehicle, isNull);
      expect(driver.isActive, isFalse);
      expect(driver.licenseStatus, ExpiryStatus.expired);
    });

    test('a missing licence expiry is rejected', () {
      expect(
        () => Driver.fromJson({...driverJson(), 'licenseExpiry': null}),
        throwsFormatException,
      );
    });
  });

  test('DriverInput sends the normalized phone and an ISO date', () {
    final input = DriverInput(
      fullName: '  Rahim Uddin ',
      phone: '+880 1711-000001',
      licenseNumber: ' dk-0123 ',
      licenseExpiry: DateTime(2027, 3, 31),
      status: DriverStatus.inactive,
    );

    expect(input.toJson(), {
      'fullName': 'Rahim Uddin',
      'phone': '01711000001',
      'licenseNumber': 'dk-0123',
      'licenseExpiry': '2027-03-31',
      'status': 'INACTIVE',
    });
  });

  group('DriverQuery', () {
    test('defaults to fullName ascending', () {
      expect(const DriverQuery().toQueryParameters(), {
        'page': 0,
        'size': 20,
        'sort': 'fullName,asc',
      });
    });

    test('adds search, status and available, caps size at 100', () {
      const query = DriverQuery(
        size: 500,
        search: ' rahim ',
        status: DriverStatus.active,
        available: true,
        sortField: DriverSortField.licenseExpiry,
        sortDirection: SortDirection.descending,
      );
      expect(query.toQueryParameters(), {
        'page': 0,
        'size': 100,
        'sort': 'licenseExpiry,desc',
        'search': 'rahim',
        'status': 'ACTIVE',
        'available': true,
      });
    });

    test('copyWith can clear the status filter', () {
      const query = DriverQuery(status: DriverStatus.active);
      expect(query.copyWith(status: null).status, isNull);
      expect(query.copyWith(page: 2).status, DriverStatus.active);
    });
  });
}
