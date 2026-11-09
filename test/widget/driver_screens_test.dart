import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/utils/clock.dart';
import 'package:stark_vms_frontend/features/assignments/data/assignment_repository.dart';
import 'package:stark_vms_frontend/features/auth/data/auth_models.dart';
import 'package:stark_vms_frontend/features/auth/presentation/auth_controller.dart';
import 'package:stark_vms_frontend/features/drivers/data/driver.dart';
import 'package:stark_vms_frontend/features/drivers/data/driver_repository.dart';
import 'package:stark_vms_frontend/features/drivers/presentation/driver_detail_screen.dart';
import 'package:stark_vms_frontend/features/drivers/presentation/driver_form_screen.dart';
import 'package:stark_vms_frontend/features/drivers/presentation/drivers_list_screen.dart';
import 'package:stark_vms_frontend/shared/models/expiry_status.dart';

import '../helpers/fakes.dart';
import '../helpers/fakes_v2.dart';
import '../helpers/pump_app.dart';

void main() {
  late FakeDriverRepository drivers;

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    User user = staffUser,
    Size size = const Size(1400, 1000),
  }) async {
    await pumpScreen(
      tester,
      screen,
      size: size,
      overrides: [
        driverRepositoryProvider.overrideWithValue(drivers),
        assignmentRepositoryProvider.overrideWithValue(
          FakeAssignmentRepository(history: [testAssignment(driverId: 4)]),
        ),
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 11, 18))),
        authControllerProvider.overrideWith(
          () => FakeAuthController(AuthState.signedIn(sessionFor(user))),
        ),
      ],
    );
  }

  setUp(() {
    drivers = FakeDriverRepository(
      seed: [
        testDriver(
          id: 4,
          fullName: 'Rahim Uddin',
          currentVehicle: const VehicleSummary(
            id: 12,
            vehicleNumber: 'DHK-1234',
          ),
        ),
        testDriver(
          id: 5,
          fullName: 'Karim Mia',
          phone: '01811000002',
          licenseStatus: ExpiryStatus.expiringSoon,
          daysUntilLicenseExpiry: 9,
          status: DriverStatus.inactive,
        ),
      ],
    );
  });

  group('DriversListScreen (FR-DR01)', () {
    testWidgets('rows with licence badge and current vehicle', (tester) async {
      await pump(tester, const DriversListScreen());

      expect(find.byKey(const Key('drivers.table')), findsOneWidget);
      expect(find.text('Rahim Uddin'), findsOneWidget);
      expect(find.text('DHK-1234'), findsOneWidget);
      expect(find.text('Expires in 9 days'), findsOneWidget);
      expect(find.text('Not assigned'), findsOneWidget);
      expect(find.text('2 drivers'), findsOneWidget);
      expect(find.byKey(const ValueKey('driver.delete.4')), findsNothing);
    });

    testWidgets('debounced search, status filter and sort go to the server', (
      tester,
    ) async {
      await pump(tester, const DriversListScreen(), user: adminUser);
      expect(find.byKey(const ValueKey('driver.delete.4')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('drivers.search')), 'rah');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(drivers.listQueries.last.toQueryParameters()['search'], 'rah');

      await tester.tap(find.byKey(const Key('drivers.statusFilter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Active').last);
      await tester.pumpAndSettle();
      expect(drivers.listQueries.last.toQueryParameters()['status'], 'ACTIVE');

      await tester.tap(find.text('Licence expiry'));
      await tester.pumpAndSettle();
      expect(
        drivers.listQueries.last.toQueryParameters()['sort'],
        'licenseExpiry,asc',
      );
    });

    testWidgets('cards on phones', (tester) async {
      await pump(tester, const DriversListScreen(), size: const Size(400, 900));
      expect(find.byKey(const ValueKey('driver.card.4')), findsOneWidget);
    });
  });

  group('DriverFormScreen', () {
    testWidgets('validates phone format on the client', (tester) async {
      await pump(tester, const DriverFormScreen());

      await tester.enterText(
        find.byKey(const Key('driverForm.fullName')),
        'New Driver',
      );
      await tester.enterText(
        find.byKey(const Key('driverForm.phone')),
        '12345',
      );
      await tester.tap(find.byKey(const Key('driverForm.save')));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter a Bangladeshi mobile number, e.g. 01711-000001.'),
        findsOneWidget,
      );
      expect(find.text('Licence number is required.'), findsOneWidget);
      expect(find.text('Licence expiry date is required.'), findsOneWidget);
      expect(drivers.saved, isEmpty);
    });

    testWidgets('server duplicate phone is shown under the phone field', (
      tester,
    ) async {
      const detail =
          'Phone number 01711000001 is already registered to another driver.';
      drivers.saveError = problem(
        409,
        type: 'duplicate-driver-phone',
        title: 'Duplicate phone number',
        detail: detail,
        errors: const [
          {'field': 'phone', 'message': detail},
        ],
      );
      await pump(tester, const DriverFormScreen(driverId: 5));

      await tester.enterText(
        find.byKey(const Key('driverForm.phone')),
        '01711-000001',
      );
      await tester.tap(find.byKey(const Key('driverForm.save')));
      await tester.pumpAndSettle();

      expect(drivers.saved.single.toJson()['phone'], '01711000001');
      expect(
        find.descendant(
          of: find.byKey(const Key('driverForm.phone')),
          matching: find.text(detail),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('driverForm.licenseNumber')),
          matching: find.text(detail),
        ),
        findsNothing,
      );
    });

    testWidgets('duplicate licence without errors[] goes under licence', (
      tester,
    ) async {
      const detail =
          'Licence number DK0123456L00005 is already registered to another driver.';
      drivers.saveError = problem(
        409,
        type: 'duplicate-driver-license',
        detail: detail,
      );
      await pump(tester, const DriverFormScreen(driverId: 5));

      await tester.tap(find.byKey(const Key('driverForm.save')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('driverForm.licenseNumber')),
          matching: find.text(detail),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('DriverDetailScreen shows info and assignment history', (
    tester,
  ) async {
    await pump(tester, const DriverDetailScreen(driverId: 4));

    expect(find.byKey(const Key('driverDetail.name')), findsOneWidget);
    expect(find.byKey(const Key('driverDetail.vehicle')), findsOneWidget);
    expect(find.byKey(const Key('assignments.history')), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
  });
}
