import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/features/assignments/data/assignment_repository.dart';
import 'package:stark_vms_frontend/features/assignments/presentation/assign_driver_dialog.dart';
import 'package:stark_vms_frontend/features/auth/presentation/auth_controller.dart';
import 'package:stark_vms_frontend/features/drivers/data/driver.dart';
import 'package:stark_vms_frontend/features/drivers/data/driver_repository.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_repository.dart';

import '../helpers/fakes.dart';
import '../helpers/fakes_v2.dart';
import '../helpers/pump_app.dart';

void main() {
  const tc10Detail =
      'Driver Rahim Uddin is already assigned to vehicle DHK-5678. '
      'Unassign them first.';

  Future<(FakeDriverRepository, FakeAssignmentRepository)> pumpDialog(
    WidgetTester tester, {
    FakeAssignmentRepository? assignments,
  }) async {
    final drivers = FakeDriverRepository(
      seed: [
        testDriver(id: 4, fullName: 'Rahim Uddin'),
        testDriver(
          id: 5,
          fullName: 'Karim Mia',
          currentVehicle: const VehicleSummary(
            id: 7,
            vehicleNumber: 'DHK-5678',
          ),
        ),
      ],
    );
    final assignmentRepository = assignments ?? FakeAssignmentRepository();
    await pumpScreen(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              key: const Key('open'),
              onPressed: () =>
                  showAssignDriverDialog(context, vehicle: testVehicle(id: 12)),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
      overrides: [
        driverRepositoryProvider.overrideWithValue(drivers),
        assignmentRepositoryProvider.overrideWithValue(assignmentRepository),
        vehicleRepositoryProvider.overrideWithValue(
          FakeVehicleRepository(seed: [testVehicle(id: 12)]),
        ),
        authControllerProvider.overrideWith(
          () => FakeAuthController(AuthState.signedIn(sessionFor(staffUser))),
        ),
      ],
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    return (drivers, assignmentRepository);
  }

  testWidgets('lists only available drivers (available=true, ACTIVE)', (
    tester,
  ) async {
    final (drivers, _) = await pumpDialog(tester);

    final query = drivers.listQueries.last.toQueryParameters();
    expect(query['available'], true);
    expect(query['status'], 'ACTIVE');
    expect(find.text('Rahim Uddin'), findsOneWidget);
    expect(find.text('Karim Mia'), findsNothing);
  });

  testWidgets('assigns the chosen driver', (tester) async {
    final (_, assignments) = await pumpDialog(tester);

    await tester.tap(find.byKey(const ValueKey('assignDialog.driver.4')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('assignDialog.assign')));
    await tester.pumpAndSettle();

    expect(assignments.assignCalls, [(12, 4)]);
    expect(find.byKey(const Key('assignDialog')), findsNothing);
  });

  testWidgets('shows the 409 driver-already-assigned detail (TC-10)', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      assignments: FakeAssignmentRepository(
        assignError: problem(
          409,
          type: 'driver-already-assigned',
          title: 'Driver already assigned',
          detail: tc10Detail,
          errors: const [
            {'field': 'driverId', 'message': tc10Detail},
          ],
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('assignDialog.includeAssigned')));
    await tester.pumpAndSettle();
    expect(find.text('Karim Mia'), findsOneWidget);
    expect(find.text('01711000001 · drives DHK-5678'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('assignDialog.driver.5')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('assignDialog.assign')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('assignDialog.error')), findsOneWidget);
    expect(find.text(tc10Detail), findsOneWidget);
    expect(find.text('Driver already assigned'), findsOneWidget);
    // The dialog stays open so the user can pick someone else.
    expect(find.byKey(const Key('assignDialog')), findsOneWidget);
  });
}
