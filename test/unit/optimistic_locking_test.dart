import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/network/api_exception.dart';
import 'package:stark_vms_frontend/core/network/form_errors.dart';
import 'package:stark_vms_frontend/core/utils/change_tracker.dart';
import 'package:stark_vms_frontend/features/drivers/data/driver.dart';
import 'package:stark_vms_frontend/features/drivers/data/driver_repository.dart';
import 'package:stark_vms_frontend/features/drivers/presentation/driver_form_controller.dart';
import 'package:stark_vms_frontend/features/drivers/presentation/driver_providers.dart';
import 'package:stark_vms_frontend/features/maintenance/data/maintenance_record.dart';
import 'package:stark_vms_frontend/features/maintenance/data/maintenance_repository.dart';
import 'package:stark_vms_frontend/features/maintenance/presentation/maintenance_providers.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_enums.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_repository.dart';
import 'package:stark_vms_frontend/features/vehicles/presentation/vehicle_form_controller.dart';

import '../helpers/fakes.dart';
import '../helpers/fakes_v2.dart';
import '../helpers/recording_adapter.dart';

/// v2.1 optimistic locking (ADR 0023, contract 7.2): every loaded record
/// keeps its `version`, every PUT sends it back, creates never send it, and
/// a 409 `stale-version` is recognised as such.
void main() {
  const staleDetail =
      'This vehicle was changed by someone else since you opened it. Reload '
      'and try again.';
  final stale = problem(
    409,
    type: 'stale-version',
    title: 'Record changed',
    detail: staleDetail,
  );

  group('version in responses (7.2.1)', () {
    test('Vehicle, Driver and MaintenanceRecord parse version', () {
      expect(
        Vehicle.fromJson({
          'id': 1,
          'vehicleNumber': 'DHK-1',
          'vehicleType': 'CAR',
          'version': 3,
        }).version,
        3,
      );
      expect(
        Driver.fromJson({
          'id': 4,
          'fullName': 'Rahim Uddin',
          'licenseExpiry': '2027-03-31',
          'version': 5,
        }).version,
        5,
      );
      expect(
        MaintenanceRecord.fromJson({
          'id': 1,
          'vehicleId': 12,
          'serviceDate': '2026-11-10',
          'version': 2,
        }).version,
        2,
      );
    });

    test('a missing version reads as 0 (new record)', () {
      expect(
        Vehicle.fromJson({
          'id': 1,
          'vehicleNumber': 'DHK-1',
          'vehicleType': 'CAR',
        }).version,
        0,
      );
    });
  });

  group('version in PUT bodies (7.2.2)', () {
    const vehicleInput = VehicleInput(
      vehicleNumber: 'DHK-1234',
      vehicleType: VehicleType.car,
    );
    final driverInput = DriverInput(
      fullName: 'Rahim Uddin',
      phone: '01711-000001',
      licenseNumber: 'DK0123456L00001',
      licenseExpiry: DateTime(2027, 3, 31),
    );
    final maintenanceInput = MaintenanceInput(
      serviceDate: DateTime(2026, 11, 10),
      maintenanceType: MaintenanceType.oilChange,
      cost: 3500,
    );

    test('update bodies carry the version, create bodies do not', () {
      expect(vehicleInput.toUpdateJson(3)['version'], 3);
      expect(vehicleInput.toJson().containsKey('version'), isFalse);
      expect(driverInput.toUpdateJson(5)['version'], 5);
      expect(driverInput.toJson().containsKey('version'), isFalse);
      expect(maintenanceInput.toUpdateJson(0)['version'], 0);
      expect(maintenanceInput.toJson().containsKey('version'), isFalse);
      expect(
        vehicleInput.toUpdateJson(3)..remove('version'),
        vehicleInput.toJson(),
      );
    });

    test('the API repositories send version in PUT and not in POST', () async {
      final adapter = RecordingAdapter((request) {
        if (request.path.startsWith('/vehicles')) {
          return const CannedResponse(
            200,
            body: {
              'id': 1,
              'vehicleNumber': 'DHK-1234',
              'vehicleType': 'CAR',
              'version': 4,
            },
          );
        }
        if (request.path.startsWith('/drivers')) {
          return const CannedResponse(
            200,
            body: {
              'id': 4,
              'fullName': 'Rahim Uddin',
              'licenseExpiry': '2027-03-31',
              'version': 6,
            },
          );
        }
        return const CannedResponse(
          200,
          body: {
            'id': 9,
            'vehicleId': 12,
            'serviceDate': '2026-11-10',
            'version': 1,
          },
        );
      });
      final client = apiClientFor(adapter);

      final vehicle = await ApiVehicleRepository(client)
          .update(1, vehicleInput, version: 3);
      expect(adapter.last.method, 'PUT');
      expect(adapter.last.path, '/vehicles/1');
      expect((adapter.last.data as Map)['version'], 3);
      expect(vehicle.version, 4);

      await ApiVehicleRepository(client).create(vehicleInput);
      expect(adapter.last.method, 'POST');
      expect((adapter.last.data as Map).containsKey('version'), isFalse);

      await ApiDriverRepository(client).update(4, driverInput, version: 5);
      expect(adapter.last.path, '/drivers/4');
      expect((adapter.last.data as Map)['version'], 5);

      await ApiMaintenanceRepository(client)
          .update(9, maintenanceInput, version: 0);
      expect(adapter.last.path, '/maintenance/9');
      expect((adapter.last.data as Map)['version'], 0);
    });
  });

  group('409 stale-version (7.2.3)', () {
    test('ApiException.isStaleVersion matches only that 409', () {
      expect(stale.isStaleVersion, isTrue);
      expect(stale.message, staleDetail);
      expect(stale.fieldErrors, isEmpty);
      expect(
        problem(
          409,
          type: 'duplicate-vehicle-number',
          detail: 'x',
        ).isStaleVersion,
        isFalse,
      );
      expect(
        problem(400, type: 'stale-version', detail: 'x').isStaleVersion,
        isFalse,
      );
    });

    test('FormSubmitState.failed keeps a stale version apart', () {
      final state = FormSubmitState.failed(stale, fields: const {'brand'});
      expect(state.isStale, isTrue);
      expect(state.staleVersionMessage, staleDetail);
      expect(state.errorMessage, isNull);
      expect(state.withoutStaleVersion().isStale, isFalse);

      final other = FormSubmitState.failed(
        problem(409, type: 'conflict', detail: 'Other conflict.'),
        fields: const {'brand'},
      );
      expect(other.isStale, isFalse);
      expect(other.errorMessage, 'Other conflict.');
    });
  });

  group('controllers send the loaded version', () {
    test('VehicleFormController updates with existing.version', () async {
      final repository = FakeVehicleRepository(
        seed: [testVehicle(id: 7, version: 3)],
      );
      final container = ProviderContainer(
        overrides: [vehicleRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        vehicleFormControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      final saved = await container
          .read(vehicleFormControllerProvider.notifier)
          .submit(
            existing: repository.vehicles.single,
            input: const VehicleInput(
              vehicleNumber: 'DHK-7',
              vehicleType: VehicleType.car,
            ),
          );

      expect(repository.updateVersions, [3]);
      expect(saved?.version, 4);
    });

    test('a stale vehicle save sets isStale, not a field error', () async {
      final repository = FakeVehicleRepository(
        seed: [testVehicle(id: 7, version: 1)],
        saveError: stale,
      );
      final container = ProviderContainer(
        overrides: [vehicleRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        vehicleFormControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      final saved = await container
          .read(vehicleFormControllerProvider.notifier)
          .submit(
            existing: repository.vehicles.single,
            input: const VehicleInput(
              vehicleNumber: 'DHK-7',
              vehicleType: VehicleType.car,
            ),
          );

      final state = container.read(vehicleFormControllerProvider);
      expect(saved, isNull);
      expect(state.staleVersionMessage, staleDetail);
      expect(state.errors.fieldErrors, isEmpty);
      expect(state.errorMessage, isNull);
    });

    test('DriverFormController updates with existing.version', () async {
      final repository = FakeDriverRepository(seed: [testDriver(version: 5)]);
      final container = ProviderContainer(
        overrides: [driverRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        driverFormControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final driver = repository.drivers.single;

      await container
          .read(driverFormControllerProvider.notifier)
          .submit(
            existing: driver,
            input: DriverInput(
              fullName: driver.fullName,
              phone: driver.phone,
              licenseNumber: driver.licenseNumber,
              licenseExpiry: driver.licenseExpiry,
            ),
          );

      expect(repository.updateVersions, [5]);
    });

    test('DriverActions.deactivate sends the version; stale refreshes the '
        'drivers and rethrows', () async {
      final repository = FakeDriverRepository(seed: [testDriver(version: 2)]);
      final container = ProviderContainer(
        overrides: [driverRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container
          .read(driverActionsProvider)
          .deactivate(repository.drivers.single);
      expect(repository.updateVersions, [2]);

      repository.saveError = stale;
      final before = container.read(driverChangesProvider);
      await expectLater(
        container
            .read(driverActionsProvider)
            .deactivate(repository.drivers.single),
        throwsA(isA<ApiException>().having((e) => e.isStaleVersion, '', true)),
      );
      expect(container.read(driverChangesProvider), before + 1);
    });

    test('MaintenanceFormController updates with existing.version and '
        'reload returns the fresh record', () async {
      final repository = FakeMaintenanceRepository(
        seed: [testMaintenance(id: 3, version: 4)],
      );
      final container = ProviderContainer(
        overrides: [
          maintenanceRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        maintenanceFormControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final controller = container.read(
        maintenanceFormControllerProvider.notifier,
      );

      repository.updateError = stale;
      await controller.submit(
        vehicleId: 12,
        existing: repository.records.single,
        input: MaintenanceInput(
          serviceDate: DateTime(2026, 11, 1),
          maintenanceType: MaintenanceType.oilChange,
          cost: 10,
        ),
      );
      expect(repository.updateVersions, [4]);
      expect(container.read(maintenanceFormControllerProvider).isStale, true);

      repository.records[0] = testMaintenance(id: 3, version: 5, cost: 99);
      final changesBefore = container.read(maintenanceChangesProvider);
      final fresh = await controller.reload(3);
      expect(fresh.version, 5);
      expect(fresh.cost, 99);
      expect(container.read(maintenanceChangesProvider), changesBefore + 1);
      expect(container.read(maintenanceFormControllerProvider).isStale, false);
    });
  });
}
