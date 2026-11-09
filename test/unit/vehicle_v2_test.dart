import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/features/auth/presentation/auth_controller.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_enums.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_query.dart';
import 'package:stark_vms_frontend/features/vehicles/presentation/vehicle_detail_tab.dart';
import 'package:stark_vms_frontend/features/vehicles/presentation/vehicle_providers.dart';

import '../helpers/fakes.dart';

void main() {
  test('VehicleResponse with currentDriver (contract 6.2)', () {
    final vehicle = Vehicle.fromJson({
      'id': 12,
      'vehicleNumber': 'DHK-1234',
      'vehicleType': 'CAR',
      'status': 'ACTIVE',
      'currentDriver': {
        'id': 4,
        'fullName': 'Rahim Uddin',
        'phone': '01711000001',
      },
    });

    expect(vehicle.currentDriver?.id, 4);
    expect(vehicle.currentDriver?.fullName, 'Rahim Uddin');
    expect(vehicle.currentDriver?.phone, '01711000001');
  });

  test('currentDriver null or missing means no driver', () {
    final vehicle = Vehicle.fromJson({
      'id': 12,
      'vehicleNumber': 'DHK-1234',
      'vehicleType': 'CAR',
      'currentDriver': null,
    });
    expect(vehicle.currentDriver, isNull);
  });

  test('status and type filters become query parameters (FR-V09)', () {
    const query = VehicleQuery(
      search: 'rahim',
      status: VehicleStatus.maintenance,
      type: VehicleType.bus,
    );
    expect(query.toQueryParameters(), {
      'page': 0,
      'size': 20,
      'sort': 'createdAt,desc',
      'search': 'rahim',
      'status': 'MAINTENANCE',
      'type': 'BUS',
    });
  });

  test('URL values parse case-insensitively, unknown ones are null', () {
    expect(VehicleStatus.tryParse('maintenance'), VehicleStatus.maintenance);
    expect(VehicleStatus.tryParse('BROKEN'), isNull);
    expect(VehicleType.tryParse('TRUCK'), VehicleType.truck);
    expect(VehicleDetailTab.fromQuery('documents'), VehicleDetailTab.documents);
    expect(VehicleDetailTab.fromQuery(null), VehicleDetailTab.overview);
  });

  group('VehicleQueryController filters', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(AuthState.signedIn(sessionFor(adminUser))),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    test('changing a filter resets the page to 0', () {
      final controller = container.read(vehicleQueryProvider.notifier)
        ..goToPage(3);
      controller.setStatus(VehicleStatus.active);
      expect(container.read(vehicleQueryProvider).page, 0);
      expect(container.read(vehicleQueryProvider).status, VehicleStatus.active);

      controller
        ..goToPage(2)
        ..setType(VehicleType.truck);
      expect(container.read(vehicleQueryProvider).page, 0);
      expect(container.read(vehicleQueryProvider).type, VehicleType.truck);
    });

    test('showOnly replaces filters and clears search, keeps sort', () {
      container.read(vehicleQueryProvider.notifier)
        ..setSearch('dhk')
        ..setType(VehicleType.bus)
        ..sortBy(VehicleSortField.vehicleNumber)
        ..showOnly(status: VehicleStatus.inactive);

      final query = container.read(vehicleQueryProvider);
      expect(query.status, VehicleStatus.inactive);
      expect(query.type, isNull);
      expect(query.search, '');
      expect(query.sortField, VehicleSortField.vehicleNumber);
    });
  });
}
