import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_enums.dart';

void main() {
  group('Vehicle.fromJson (FR-V01)', () {
    test('parses a full VehicleResponse', () {
      final vehicle = Vehicle.fromJson({
        'id': 12,
        'vehicleNumber': 'DHAKA METRO-GA 11-2345',
        'vehicleType': 'CAR',
        'brand': 'Toyota',
        'model': 'Axio',
        'manufactureYear': 2019,
        'color': 'White',
        'fuelType': 'OCTANE',
        'status': 'ACTIVE',
        'createdAt': '2026-11-06T09:15:00Z',
        'updatedAt': '2026-11-06T10:20:30.123+06:00',
        'createdBy': 'admin@stark.local',
      });

      expect(vehicle.id, 12);
      expect(vehicle.vehicleNumber, 'DHAKA METRO-GA 11-2345');
      expect(vehicle.vehicleType, VehicleType.car);
      expect(vehicle.fuelType, FuelType.octane);
      expect(vehicle.status, VehicleStatus.active);
      expect(vehicle.brandModel, 'Toyota Axio');
      expect(vehicle.createdAt, DateTime.utc(2026, 11, 6, 9, 15));
      expect(vehicle.updatedAt, DateTime.utc(2026, 11, 6, 4, 20, 30, 123));
      expect(vehicle.createdBy, 'admin@stark.local');
    });

    test('accepts null optional fields', () {
      final vehicle = Vehicle.fromJson({
        'id': 3,
        'vehicleNumber': 'DHK-1',
        'vehicleType': 'TRUCK',
        'brand': null,
        'model': null,
        'manufactureYear': null,
        'color': null,
        'fuelType': null,
        'status': 'MAINTENANCE',
        'createdAt': null,
        'updatedAt': null,
        'createdBy': null,
      });

      expect(vehicle.brand, isNull);
      expect(vehicle.model, isNull);
      expect(vehicle.brandModel, isNull);
      expect(vehicle.manufactureYear, isNull);
      expect(vehicle.fuelType, isNull);
      expect(vehicle.status, VehicleStatus.maintenance);
      expect(vehicle.createdAt, isNull);
    });

    test('rejects a body without id or vehicle number', () {
      expect(
        () => Vehicle.fromJson({'vehicleType': 'CAR'}),
        throwsFormatException,
      );
    });

    test('rejects unknown enum values', () {
      expect(
        () => Vehicle.fromJson({
          'id': 1,
          'vehicleNumber': 'X1',
          'vehicleType': 'SPACESHIP',
          'status': 'ACTIVE',
        }),
        throwsFormatException,
      );
    });

    test('toJson round-trips', () {
      final json = {
        'id': 5,
        'vehicleNumber': 'DHK-5',
        'vehicleType': 'BUS',
        'brand': 'Hino',
        'model': null,
        'manufactureYear': 2015,
        'color': null,
        'fuelType': 'DIESEL',
        'status': 'INACTIVE',
        'createdAt': '2026-11-06T09:15:00.000Z',
        'updatedAt': '2026-11-06T09:15:00.000Z',
        'createdBy': 'staff@stark.local',
        'version': 4,
      };
      expect(Vehicle.fromJson(Vehicle.fromJson(json).toJson()).toJson(), json);
    });
  });

  group('VehicleInput.toJson', () {
    test('trims text and sends blank optional fields as null', () {
      const input = VehicleInput(
        vehicleNumber: '  DHK-1234 ',
        vehicleType: VehicleType.suv,
        brand: ' ',
        model: ' Prado ',
        color: '',
      );

      expect(input.toJson(), {
        'vehicleNumber': 'DHK-1234',
        'vehicleType': 'SUV',
        'brand': null,
        'model': 'Prado',
        'manufactureYear': null,
        'color': null,
        'fuelType': null,
      });
    });
  });
}
