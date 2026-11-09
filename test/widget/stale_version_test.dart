import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/utils/clock.dart';
import 'package:stark_vms_frontend/features/auth/presentation/auth_controller.dart';
import 'package:stark_vms_frontend/features/drivers/data/driver_repository.dart';
import 'package:stark_vms_frontend/features/drivers/presentation/driver_form_screen.dart';
import 'package:stark_vms_frontend/features/maintenance/data/maintenance_repository.dart';
import 'package:stark_vms_frontend/features/maintenance/presentation/maintenance_tab.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_repository.dart';
import 'package:stark_vms_frontend/features/vehicles/presentation/vehicle_form_screen.dart';
import 'package:stark_vms_frontend/shared/widgets/stale_version_dialog.dart';

import '../helpers/fakes.dart';
import '../helpers/fakes_v2.dart';
import '../helpers/pump_app.dart';

/// 409 stale-version in the edit forms (ADR 0023, contract 7.2.4): the
/// dialog explains, Cancel keeps the edits, Reload refills from the server
/// and the next save sends the new version.
void main() {
  String staleDetail(String record) =>
      'This $record was changed by someone else since you opened it. '
      'Reload and try again.';

  final signedIn = authControllerProvider.overrideWith(
    () => FakeAuthController(AuthState.signedIn(sessionFor(staffUser))),
  );

  Finder fieldText(String key, String text) =>
      find.descendant(of: find.byKey(Key(key)), matching: find.text(text));

  testWidgets('vehicle form: Cancel keeps edits, Reload refills and the next '
      'save sends the new version', (tester) async {
    final repository = FakeVehicleRepository(
      seed: [testVehicle(id: 7, vehicleNumber: 'DHK-7777', version: 1)],
      saveError: problem(
        409,
        type: 'stale-version',
        title: 'Record changed',
        detail: staleDetail('vehicle'),
      ),
    );
    await pumpScreen(
      tester,
      const VehicleFormScreen(vehicleId: 7),
      overrides: [
        vehicleRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 11, 18))),
        signedIn,
      ],
    );

    await tester.enterText(find.byKey(const Key('vehicleForm.brand')), 'Honda');
    await tester.tap(find.byKey(const Key('vehicleForm.save')));
    await tester.pumpAndSettle();

    expect(find.text(StaleVersionDialog.title), findsOneWidget);
    expect(find.textContaining(staleDetail('vehicle')), findsOneWidget);
    expect(
      find.textContaining(StaleVersionDialog.discardWarning),
      findsOneWidget,
    );
    expect(repository.updateVersions, [1]);

    await tester.tap(find.byKey(const Key('staleVersion.cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('staleVersion.dialog')), findsNothing);
    expect(fieldText('vehicleForm.brand', 'Honda'), findsOneWidget);

    // Meanwhile someone else saved version 2.
    repository.vehicles[0] = testVehicle(
      id: 7,
      vehicleNumber: 'DHK-7777',
      brand: 'Nissan',
      version: 2,
    );
    await tester.tap(find.byKey(const Key('vehicleForm.save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('staleVersion.reload')));
    await tester.pumpAndSettle();

    expect(fieldText('vehicleForm.brand', 'Nissan'), findsOneWidget);
    expect(fieldText('vehicleForm.brand', 'Honda'), findsNothing);
    expect(find.text(StaleVersionDialog.reloadedMessage), findsOneWidget);

    repository.saveError = null;
    await tester.tap(find.byKey(const Key('vehicleForm.save')));
    await tester.pumpAndSettle();
    expect(repository.updateVersions, [1, 1, 2]);
    expect(find.text('Navigated to /vehicles/7'), findsOneWidget);
  });

  testWidgets('driver form sends the version and reloads on stale-version', (
    tester,
  ) async {
    final drivers = FakeDriverRepository(
      seed: [testDriver(id: 4, fullName: 'Rahim Uddin', version: 5)],
    );
    await pumpScreen(
      tester,
      const DriverFormScreen(driverId: 4),
      overrides: [
        driverRepositoryProvider.overrideWithValue(drivers),
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 11, 18))),
        signedIn,
      ],
    );

    drivers.saveError = problem(
      409,
      type: 'stale-version',
      detail: staleDetail('driver'),
    );
    await tester.enterText(
      find.byKey(const Key('driverForm.fullName')),
      'Rahim U.',
    );
    await tester.tap(find.byKey(const Key('driverForm.save')));
    await tester.pumpAndSettle();
    expect(drivers.updateVersions, [5]);
    expect(find.textContaining(staleDetail('driver')), findsOneWidget);

    drivers.drivers[0] = testDriver(id: 4, fullName: 'Rahim Ahmed', version: 6);
    await tester.tap(find.byKey(const Key('staleVersion.reload')));
    await tester.pumpAndSettle();
    expect(fieldText('driverForm.fullName', 'Rahim Ahmed'), findsOneWidget);

    drivers.saveError = null;
    await tester.tap(find.byKey(const Key('driverForm.save')));
    await tester.pumpAndSettle();
    expect(drivers.updateVersions, [5, 6]);
    expect(find.text('Navigated to /drivers/4'), findsOneWidget);
  });

  testWidgets('maintenance dialog reloads the record on stale-version', (
    tester,
  ) async {
    final repository = FakeMaintenanceRepository(
      seed: [testMaintenance(id: 1, version: 0)],
    );
    await pumpScreen(
      tester,
      const Scaffold(body: MaintenanceTab(vehicleId: 12)),
      overrides: [
        maintenanceRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 11, 18))),
        signedIn,
      ],
    );

    final edit = find.byKey(const ValueKey('maintenance.edit.1'));
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    await tester.tap(edit);
    await tester.pumpAndSettle();
    repository.updateError = problem(
      409,
      type: 'stale-version',
      detail: staleDetail('maintenance record'),
    );
    await tester.enterText(
      find.byKey(const Key('maintenanceDialog.vendor')),
      'My edit',
    );
    await tester.tap(find.byKey(const Key('maintenanceDialog.save')));
    await tester.pumpAndSettle();
    expect(find.textContaining(staleDetail('maintenance record')), findsOne);

    repository.records[0] = testMaintenance(
      id: 1,
      vendorName: 'Rangs Workshop',
      version: 1,
    );
    await tester.tap(find.byKey(const Key('staleVersion.reload')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('maintenanceDialog')), findsOneWidget);
    expect(
      fieldText('maintenanceDialog.vendor', 'Rangs Workshop'),
      findsOneWidget,
    );

    repository.updateError = null;
    await tester.tap(find.byKey(const Key('maintenanceDialog.save')));
    await tester.pumpAndSettle();
    expect(repository.updateVersions, [0, 1]);
    expect(find.byKey(const Key('maintenanceDialog')), findsNothing);
  });
}
