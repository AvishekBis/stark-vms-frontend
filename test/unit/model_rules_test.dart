import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/utils/enum_parsing.dart';
import 'package:stark_vms_frontend/features/drivers/data/driver.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_enums.dart';

import '../helpers/fakes.dart';
import '../helpers/fakes_v2.dart';

void main() {
  group('Vehicle rules', () {
    test('only an ACTIVE vehicle can receive a driver (BR-05)', () {
      expect(testVehicle(status: VehicleStatus.active).canReceiveDriver, true);
      expect(
        testVehicle(status: VehicleStatus.maintenance).canReceiveDriver,
        false,
      );
      expect(
        testVehicle(status: VehicleStatus.inactive).canReceiveDriver,
        false,
      );
    });

    test('going INACTIVE from another status ends the assignment', () {
      final active = testVehicle(status: VehicleStatus.active);
      final maintenance = testVehicle(status: VehicleStatus.maintenance);
      final inactive = testVehicle(status: VehicleStatus.inactive);

      expect(active.endsAssignmentOn(VehicleStatus.inactive), true);
      expect(maintenance.endsAssignmentOn(VehicleStatus.inactive), true);
      expect(active.endsAssignmentOn(VehicleStatus.maintenance), false);
      expect(inactive.endsAssignmentOn(VehicleStatus.inactive), false);
    });
  });

  group('Driver.losesVehicleOn', () {
    const vehicle = VehicleSummary(id: 12, vehicleNumber: 'DHK-1234');

    test('an ACTIVE driver with a vehicle loses it when set INACTIVE', () {
      final driver = testDriver(currentVehicle: vehicle);
      expect(driver.losesVehicleOn(DriverStatus.inactive), true);
      expect(driver.losesVehicleOn(DriverStatus.active), false);
    });

    test('nothing is lost without a vehicle or when already INACTIVE', () {
      expect(testDriver().losesVehicleOn(DriverStatus.inactive), false);
      expect(
        testDriver(
          status: DriverStatus.inactive,
          currentVehicle: vehicle,
        ).losesVehicleOn(DriverStatus.inactive),
        false,
      );
    });
  });

  group('API enum parsing', () {
    String api(VehicleStatus status) => status.apiValue;

    test('parseApiEnum matches exactly and names unknown values', () {
      expect(
        parseApiEnum(VehicleStatus.values, api, 'ACTIVE', 'vehicle status'),
        VehicleStatus.active,
      );
      expect(
        () =>
            parseApiEnum(VehicleStatus.values, api, 'active', 'vehicle status'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'Unknown vehicle status: active',
          ),
        ),
      );
    });

    test('tryParseApiEnum is null for unknown values; ignoreCase for URLs', () {
      expect(tryParseApiEnum(VehicleStatus.values, api, 'BROKEN'), isNull);
      expect(tryParseApiEnum(VehicleStatus.values, api, null), isNull);
      expect(tryParseApiEnum(VehicleStatus.values, api, 'inactive'), isNull);
      expect(
        tryParseApiEnum(
          VehicleStatus.values,
          api,
          'inactive',
          ignoreCase: true,
        ),
        VehicleStatus.inactive,
      );
    });

    test('Vehicle.fromJson still rejects an unknown status', () {
      expect(
        () => Vehicle.fromJson({
          'id': 1,
          'vehicleNumber': 'DHK-1',
          'vehicleType': 'CAR',
          'status': 'BROKEN',
        }),
        throwsFormatException,
      );
    });
  });
}
