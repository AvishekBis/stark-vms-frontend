import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/features/auth/data/auth_models.dart';
import 'package:stark_vms_frontend/features/auth/presentation/auth_controller.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_repository.dart';
import 'package:stark_vms_frontend/features/vehicles/presentation/vehicle_detail_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

void main() {
  Future<FakeVehicleRepository> pumpDetail(
    WidgetTester tester, {
    required User user,
    int vehicleId = 3,
  }) async {
    final repository = FakeVehicleRepository(
      seed: [testVehicle(id: 3, vehicleNumber: 'DHK-3333')],
    );
    await pumpScreen(
      tester,
      VehicleDetailScreen(vehicleId: vehicleId),
      overrides: [
        vehicleRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(
          () => FakeAuthController(AuthState.signedIn(sessionFor(user))),
        ),
      ],
    );
    return repository;
  }

  testWidgets('shows the vehicle from the API with audit fields (FR-V01)', (
    tester,
  ) async {
    await pumpDetail(tester, user: staffUser);

    expect(find.byKey(const Key('vehicleDetail.number')), findsOneWidget);
    expect(find.text('DHK-3333'), findsWidgets);
    expect(find.text('Toyota Axio'), findsOneWidget);
    expect(find.text('admin@stark.local'), findsOneWidget);
  });

  testWidgets('STAFF has no Delete button (FR-V04)', (tester) async {
    await pumpDetail(tester, user: staffUser);

    expect(find.byKey(const Key('vehicleDetail.edit')), findsOneWidget);
    expect(find.byKey(const Key('vehicleDetail.delete')), findsNothing);
  });

  testWidgets('ADMIN delete confirms, deletes and returns to the list', (
    tester,
  ) async {
    final repository = await pumpDetail(tester, user: adminUser);
    final listCallsBefore = repository.listQueries.length;

    await tester.tap(find.byKey(const Key('vehicleDetail.delete')));
    await tester.pumpAndSettle();
    expect(find.text('Delete vehicle?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm.ok')));
    await tester.pumpAndSettle();

    expect(repository.vehicles, isEmpty);
    expect(repository.listQueries.length, listCallsBefore);
    expect(find.text('Navigated to /vehicles'), findsOneWidget);
  });

  testWidgets('an unknown id shows the error state with Retry', (tester) async {
    await pumpDetail(tester, user: staffUser, vehicleId: 404);

    expect(find.text('The requested record was not found.'), findsOneWidget);
    expect(find.byKey(const Key('error.retry')), findsOneWidget);
  });
}
