import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/utils/change_tracker.dart';
import 'package:stark_vms_frontend/features/drivers/data/driver.dart';
import 'package:stark_vms_frontend/features/drivers/data/driver_repository.dart';
import 'package:stark_vms_frontend/features/drivers/presentation/driver_providers.dart';

import '../helpers/fakes_v2.dart';

void main() {
  group('DriverActions.deactivate', () {
    late FakeDriverRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakeDriverRepository(
        seed: [
          testDriver(
            currentVehicle: const VehicleSummary(
              id: 12,
              vehicleNumber: 'DHK-1234',
            ),
          ),
        ],
      );
      container = ProviderContainer(
        overrides: [driverRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
    });

    test('saves the same driver as INACTIVE', () async {
      final driver = repository.drivers.single;

      final updated = await container
          .read(driverActionsProvider)
          .deactivate(driver);

      final sent = repository.saved.single;
      expect(sent.status, DriverStatus.inactive);
      expect(sent.fullName, driver.fullName);
      expect(sent.phone, driver.phone);
      expect(sent.licenseNumber, driver.licenseNumber);
      expect(sent.licenseExpiry, driver.licenseExpiry);
      expect(updated.status, DriverStatus.inactive);
    });

    test(
      'refreshes drivers and vehicles (the vehicle is unassigned)',
      () async {
        final driversBefore = container.read(driverChangesProvider);
        final vehiclesBefore = container.read(vehicleChangesProvider);

        await container
            .read(driverActionsProvider)
            .deactivate(repository.drivers.single);

        expect(container.read(driverChangesProvider), driversBefore + 1);
        expect(container.read(vehicleChangesProvider), vehiclesBefore + 1);
      },
    );

    test('a rejected update changes nothing', () async {
      repository.saveError = problem(
        403,
        type: 'forbidden',
        detail: 'Not allowed.',
      );

      await expectLater(
        container
            .read(driverActionsProvider)
            .deactivate(repository.drivers.single),
        throwsA(anything),
      );
      expect(container.read(driverChangesProvider), 0);
      expect(container.read(vehicleChangesProvider), 0);
    });
  });

  test('DriverActions.hasHistory matches only the 409 history conflict', () {
    expect(
      DriverActions.hasHistory(
        problem(409, type: 'driver-has-history', detail: 'Has history.'),
      ),
      isTrue,
    );
    expect(
      DriverActions.hasHistory(
        problem(409, type: 'duplicate-driver-phone', detail: 'Duplicate.'),
      ),
      isFalse,
    );
    expect(
      DriverActions.hasHistory(
        problem(400, type: 'driver-has-history', detail: 'Odd.'),
      ),
      isFalse,
    );
    expect(DriverActions.hasHistory(StateError('x')), isFalse);
  });
}
