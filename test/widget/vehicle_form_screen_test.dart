import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/network/api_exception.dart';
import 'package:stark_vms_frontend/features/auth/presentation/auth_controller.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_repository.dart';
import 'package:stark_vms_frontend/features/vehicles/presentation/vehicle_form_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

void main() {
  const duplicateMessage = 'Vehicle number DHK-1234 is already registered.';

  Future<FakeVehicleRepository> pumpForm(
    WidgetTester tester, {
    ApiException? saveError,
    int? vehicleId,
  }) async {
    final repository = FakeVehicleRepository(
      seed: [testVehicle(id: 7, vehicleNumber: 'DHK-7777')],
      saveError: saveError,
    );
    await pumpScreen(
      tester,
      VehicleFormScreen(vehicleId: vehicleId),
      overrides: [
        vehicleRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(
          () => FakeAuthController(AuthState.signedIn(sessionFor(staffUser))),
        ),
      ],
    );
    return repository;
  }

  Future<void> chooseCarType(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('vehicleForm.type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Car').last);
    await tester.pumpAndSettle();
  }

  testWidgets('validates required fields on the client (BR-03)', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.tap(find.byKey(const Key('vehicleForm.save')));
    await tester.pump();

    expect(find.text('Vehicle number is required.'), findsOneWidget);
    expect(find.text('Vehicle type is required.'), findsOneWidget);
  });

  testWidgets(
    'shows the server duplicate error under the vehicle number (FR-V05)',
    (tester) async {
      await pumpForm(
        tester,
        saveError: ApiException.fromProblemDetails({
          'type': 'https://stark-vms/errors/duplicate-vehicle-number',
          'title': 'Duplicate vehicle number',
          'status': 409,
          'detail': duplicateMessage,
          'errors': [
            {'field': 'vehicleNumber', 'message': duplicateMessage},
          ],
        }),
      );

      await tester.enterText(
        find.byKey(const Key('vehicleForm.number')),
        'dhk 1234',
      );
      await chooseCarType(tester);
      await tester.tap(find.byKey(const Key('vehicleForm.save')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('vehicleForm.number')),
          matching: find.text(duplicateMessage),
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('vehicleForm.number')),
        'DHK-9999',
      );
      await tester.pump();
      expect(find.text(duplicateMessage), findsNothing);
    },
  );

  testWidgets('edit mode is prefilled from the API (FR-V03)', (tester) async {
    await pumpForm(tester, vehicleId: 7);

    expect(find.text('Edit vehicle'), findsOneWidget);
    expect(find.text('DHK-7777'), findsOneWidget);
    expect(find.text('Toyota'), findsOneWidget);
    expect(find.text('2019'), findsOneWidget);
  });

  testWidgets('a successful save navigates to the vehicle (FR-V02)', (
    tester,
  ) async {
    final repository = await pumpForm(tester);

    await tester.enterText(
      find.byKey(const Key('vehicleForm.number')),
      'DHK-2020',
    );
    await chooseCarType(tester);
    await tester.tap(find.byKey(const Key('vehicleForm.save')));
    await tester.pumpAndSettle();

    expect(
      repository.vehicles.map((v) => v.vehicleNumber),
      contains('DHK-2020'),
    );
    expect(find.text('Navigated to /vehicles/2'), findsOneWidget);
  });

  testWidgets('server 400 field errors appear under the right field (TC-05)', (
    tester,
  ) async {
    const yearMessage = 'Manufacture year must be between 1980 and 2027.';
    const colorMessage = 'Color must be at most 30 characters.';
    await pumpForm(
      tester,
      saveError: ApiException.fromProblemDetails({
        'type': 'https://stark-vms/errors/validation',
        'title': 'Validation failed',
        'status': 400,
        'detail': 'One or more fields are invalid.',
        'errors': [
          {'field': 'manufactureYear', 'message': yearMessage},
          {'field': 'color', 'message': colorMessage},
        ],
      }),
    );

    await tester.enterText(
      find.byKey(const Key('vehicleForm.number')),
      'DHK-5555',
    );
    await chooseCarType(tester);
    await tester.tap(find.byKey(const Key('vehicleForm.save')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('vehicleForm.year')),
        matching: find.text(yearMessage),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('vehicleForm.color')),
        matching: find.text(colorMessage),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('vehicleForm.number')),
        matching: find.textContaining('must'),
      ),
      findsNothing,
    );
  });

  testWidgets('a network failure on save is reported, form stays filled', (
    tester,
  ) async {
    await pumpForm(
      tester,
      saveError: const ApiException(
        kind: ApiErrorKind.network,
        message: 'Cannot reach the server.',
      ),
    );

    await tester.enterText(
      find.byKey(const Key('vehicleForm.number')),
      'DHK-6666',
    );
    await chooseCarType(tester);
    await tester.tap(find.byKey(const Key('vehicleForm.save')));
    await tester.pumpAndSettle();

    expect(find.text('Cannot reach the server.'), findsOneWidget);
    expect(find.text('DHK-6666'), findsOneWidget);
  });
}
