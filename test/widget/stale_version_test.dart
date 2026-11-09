import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/network/api_exception.dart';
import 'package:stark_vms_frontend/core/utils/clock.dart';
import 'package:stark_vms_frontend/features/auth/presentation/auth_controller.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_repository.dart';
import 'package:stark_vms_frontend/features/vehicles/presentation/vehicle_form_screen.dart';
import 'package:stark_vms_frontend/shared/widgets/stale_version_dialog.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

/// 409 stale-version in the vehicle edit form (ADR 0023, contract 6.2): the
/// dialog explains, Cancel keeps the edits, Reload refills from the server
/// and the next save sends the new version.
void main() {
  const staleDetail =
      'This vehicle was changed by someone else since you opened it. '
      'Reload and try again.';
  final stale = ApiException.fromProblemDetails({
    'type': 'https://stark-vms/errors/stale-version',
    'title': 'Record changed',
    'status': 409,
    'detail': staleDetail,
  });

  Finder fieldText(String key, String text) =>
      find.descendant(of: find.byKey(Key(key)), matching: find.text(text));

  Future<FakeVehicleRepository> pumpEditForm(WidgetTester tester) async {
    final repository = FakeVehicleRepository(
      seed: [testVehicle(id: 7, vehicleNumber: 'DHK-7777', version: 1)],
      saveError: stale,
    );
    await pumpScreen(
      tester,
      const VehicleFormScreen(vehicleId: 7),
      overrides: [
        vehicleRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 11, 18))),
        authControllerProvider.overrideWith(
          () => FakeAuthController(AuthState.signedIn(sessionFor(staffUser))),
        ),
      ],
    );
    return repository;
  }

  testWidgets('the dialog shows the server detail and Cancel keeps the edits', (
    tester,
  ) async {
    final repository = await pumpEditForm(tester);

    await tester.enterText(find.byKey(const Key('vehicleForm.brand')), 'Honda');
    await tester.tap(find.byKey(const Key('vehicleForm.save')));
    await tester.pumpAndSettle();

    expect(find.text(StaleVersionDialog.title), findsOneWidget);
    expect(find.textContaining(staleDetail), findsOneWidget);
    expect(
      find.textContaining(StaleVersionDialog.discardWarning),
      findsOneWidget,
    );
    expect(repository.updateVersions, [1]);

    await tester.tap(find.byKey(const Key('staleVersion.cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('staleVersion.dialog')), findsNothing);
    expect(fieldText('vehicleForm.brand', 'Honda'), findsOneWidget);
    expect(find.text(StaleVersionDialog.reloadedMessage), findsNothing);
    expect(find.textContaining('Navigated to'), findsNothing);
  });

  testWidgets('Reload refills the form, says the edits were discarded and '
      'the next save sends the new version', (tester) async {
    final repository = await pumpEditForm(tester);

    await tester.enterText(find.byKey(const Key('vehicleForm.brand')), 'Honda');
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

    expect(find.byKey(const Key('staleVersion.dialog')), findsNothing);
    expect(fieldText('vehicleForm.brand', 'Nissan'), findsOneWidget);
    expect(fieldText('vehicleForm.brand', 'Honda'), findsNothing);
    expect(find.text(StaleVersionDialog.reloadedMessage), findsOneWidget);

    repository.saveError = null;
    await tester.tap(find.byKey(const Key('vehicleForm.save')));
    await tester.pumpAndSettle();

    expect(repository.updateVersions, [1, 2]);
    expect(find.text('Navigated to /vehicles/7'), findsOneWidget);
  });
}
