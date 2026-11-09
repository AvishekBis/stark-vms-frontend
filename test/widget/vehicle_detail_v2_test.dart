import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/features/assignments/data/assignment_repository.dart';
import 'package:stark_vms_frontend/features/auth/data/auth_models.dart';
import 'package:stark_vms_frontend/features/auth/presentation/auth_controller.dart';
import 'package:stark_vms_frontend/features/documents/data/document_repository.dart';
import 'package:stark_vms_frontend/features/drivers/data/driver_repository.dart';
import 'package:stark_vms_frontend/features/maintenance/data/maintenance_repository.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_enums.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_repository.dart';
import 'package:stark_vms_frontend/features/vehicles/presentation/vehicle_detail_screen.dart';
import 'package:stark_vms_frontend/features/vehicles/presentation/vehicle_detail_tab.dart';

import '../helpers/fakes.dart';
import '../helpers/fakes_v2.dart';
import '../helpers/pump_app.dart';

void main() {
  late FakeVehicleRepository vehicles;
  late FakeAssignmentRepository assignments;

  Future<void> pumpDetail(
    WidgetTester tester, {
    required User user,
    VehicleDetailTab tab = VehicleDetailTab.overview,
  }) async {
    await pumpScreen(
      tester,
      VehicleDetailScreen(vehicleId: 12, initialTab: tab),
      overrides: [
        vehicleRepositoryProvider.overrideWithValue(vehicles),
        assignmentRepositoryProvider.overrideWithValue(assignments),
        driverRepositoryProvider.overrideWithValue(FakeDriverRepository()),
        documentRepositoryProvider.overrideWithValue(
          FakeDocumentRepository(seed: [testDocument()]),
        ),
        maintenanceRepositoryProvider.overrideWithValue(
          FakeMaintenanceRepository(seed: [testMaintenance()]),
        ),
        authControllerProvider.overrideWith(
          () => FakeAuthController(AuthState.signedIn(sessionFor(user))),
        ),
      ],
    );
  }

  setUp(() {
    vehicles = FakeVehicleRepository(
      seed: [
        testVehicle(
          id: 12,
          vehicleNumber: 'DHK-1234',
          currentDriver: const DriverSummary(
            id: 4,
            fullName: 'Rahim Uddin',
            phone: '01711000001',
          ),
        ),
      ],
    );
    assignments = FakeAssignmentRepository(
      history: [
        testAssignment(id: 9),
        testAssignment(id: 8, driverId: 5, current: false),
      ],
    );
  });

  testWidgets('has the four tabs and the current driver card', (tester) async {
    await pumpDetail(tester, user: staffUser);

    for (final tab in VehicleDetailTab.values) {
      expect(find.text(tab.label), findsOneWidget);
    }
    expect(
      find.byKey(const Key('vehicleDetail.currentDriver')),
      findsOneWidget,
    );
    expect(find.text('Rahim Uddin'), findsOneWidget);
    expect(find.byKey(const Key('vehicleDetail.changeStatus')), findsNothing);
  });

  testWidgets('?tab=documents opens the Documents tab', (tester) async {
    await pumpDetail(tester, user: staffUser, tab: VehicleDetailTab.documents);

    expect(find.byKey(const Key('documents.upload')), findsOneWidget);
    expect(find.text('Expires in 12 days'), findsOneWidget);
  });

  testWidgets('Driver history tab highlights the current assignment', (
    tester,
  ) async {
    await pumpDetail(tester, user: staffUser, tab: VehicleDetailTab.drivers);

    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Ended'), findsOneWidget);
  });

  testWidgets('Unassign asks for confirmation', (tester) async {
    await pumpDetail(tester, user: staffUser);

    await tester.tap(find.byKey(const Key('vehicleDetail.unassignDriver')));
    await tester.pumpAndSettle();
    expect(find.text('Unassign driver?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm.ok')));
    await tester.pumpAndSettle();

    expect(assignments.unassignCalls, [12]);
  });

  testWidgets('ADMIN changes status; INACTIVE warns about the driver', (
    tester,
  ) async {
    await pumpDetail(tester, user: adminUser);

    await tester.tap(find.byKey(const Key('vehicleDetail.changeStatus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('statusDialog.INACTIVE')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('statusDialog.inactiveWarning')),
      findsOneWidget,
    );
    expect(
      find.textContaining('unassign its driver Rahim Uddin'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('statusDialog.save')));
    await tester.pumpAndSettle();

    expect(vehicles.statusChanges, [(12, VehicleStatus.inactive)]);
    expect(find.text('Vehicle DHK-1234 is now inactive.'), findsOneWidget);
  });

  testWidgets('delete with history offers "Set INACTIVE instead" (BR-10)', (
    tester,
  ) async {
    const detail =
        'Vehicle DHK-1234 has documents, maintenance or driver history and '
        'cannot be deleted. Set its status to INACTIVE instead.';
    vehicles.deleteError = problem(
      409,
      type: 'vehicle-has-history',
      title: 'Vehicle has history',
      detail: detail,
    );
    await pumpDetail(tester, user: adminUser);

    await tester.tap(find.byKey(const Key('vehicleDetail.delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm.ok')));
    await tester.pumpAndSettle();

    expect(find.text(detail), findsOneWidget);
    await tester.tap(find.byKey(const Key('vehicleHistoryDialog.setInactive')));
    await tester.pumpAndSettle();

    expect(vehicles.vehicles, hasLength(1));
    expect(vehicles.statusChanges, [(12, VehicleStatus.inactive)]);
  });
}
