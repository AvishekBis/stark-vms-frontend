import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/features/auth/data/auth_models.dart';
import 'package:stark_vms_frontend/features/auth/presentation/auth_controller.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_enums.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_repository.dart';
import 'package:stark_vms_frontend/features/vehicles/presentation/vehicle_list_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

void main() {
  FakeVehicleRepository seededRepository() => FakeVehicleRepository(
    seed: [
      testVehicle(id: 1, vehicleNumber: 'DHK-1234'),
      testVehicle(
        id: 2,
        vehicleNumber: 'DHAKA METRO-GA 11-2345',
        vehicleType: VehicleType.bus,
        status: VehicleStatus.maintenance,
        brand: 'Hino',
        model: null,
      ),
    ],
  );

  Future<FakeVehicleRepository> pumpList(
    WidgetTester tester, {
    required User user,
    FakeVehicleRepository? repository,
    Size size = const Size(1400, 1000),
  }) async {
    final repo = repository ?? seededRepository();
    await pumpScreen(
      tester,
      const VehicleListScreen(),
      size: size,
      overrides: [
        vehicleRepositoryProvider.overrideWithValue(repo),
        authControllerProvider.overrideWith(
          () => FakeAuthController(AuthState.signedIn(sessionFor(user))),
        ),
      ],
    );
    return repo;
  }

  testWidgets('renders rows from the repository with status badges (FR-V01)', (
    tester,
  ) async {
    await pumpList(tester, user: staffUser);

    expect(find.byKey(const Key('vehicles.table')), findsOneWidget);
    expect(find.text('DHK-1234'), findsOneWidget);
    expect(find.text('DHAKA METRO-GA 11-2345'), findsOneWidget);
    expect(find.text('Toyota Axio'), findsOneWidget);
    expect(find.text('Maintenance'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('2 vehicles'), findsOneWidget);
    expect(find.text('Page 1 of 1'), findsOneWidget);
  });

  testWidgets('STAFF sees Edit but not Delete (FR-V04)', (tester) async {
    await pumpList(tester, user: staffUser);

    expect(find.byKey(const ValueKey('vehicle.edit.1')), findsOneWidget);
    expect(find.byKey(const ValueKey('vehicle.delete.1')), findsNothing);
    expect(find.byKey(const ValueKey('vehicle.delete.2')), findsNothing);
  });

  testWidgets('ADMIN sees Delete', (tester) async {
    await pumpList(tester, user: adminUser);

    expect(find.byKey(const ValueKey('vehicle.delete.1')), findsOneWidget);
    expect(find.byKey(const ValueKey('vehicle.delete.2')), findsOneWidget);
  });

  testWidgets('ADMIN delete asks for confirmation and refreshes the list', (
    tester,
  ) async {
    final repository = await pumpList(tester, user: adminUser);

    await tester.tap(find.byKey(const ValueKey('vehicle.delete.1')));
    await tester.pumpAndSettle();
    expect(find.text('Delete vehicle?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm.ok')));
    await tester.pumpAndSettle();

    expect(repository.vehicles.map((v) => v.id), [2]);
    expect(find.text('Vehicle DHK-1234 deleted.'), findsOneWidget);
    expect(find.text('DHK-1234'), findsNothing);
    expect(find.text('1 vehicle'), findsOneWidget);
  });

  testWidgets('search is debounced and sent to the server', (tester) async {
    final repository = await pumpList(tester, user: staffUser);
    final callsBefore = repository.listQueries.length;

    await tester.enterText(find.byKey(const Key('vehicles.search')), 'dhaka');
    await tester.pump(const Duration(milliseconds: 100));
    expect(repository.listQueries.length, callsBefore);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(repository.listQueries.last.search, 'dhaka');
    expect(find.text('DHK-1234'), findsNothing);
    expect(find.text('DHAKA METRO-GA 11-2345'), findsOneWidget);
  });

  testWidgets('shows cards on narrow screens', (tester) async {
    await pumpList(tester, user: staffUser, size: const Size(400, 900));

    expect(find.byKey(const ValueKey('vehicle.card.1')), findsOneWidget);
    expect(find.byKey(const Key('vehicles.table')), findsNothing);
  });

  testWidgets('shows the empty state when there are no vehicles', (
    tester,
  ) async {
    await pumpList(
      tester,
      user: staffUser,
      repository: FakeVehicleRepository(),
    );

    expect(find.text('No vehicles registered yet'), findsOneWidget);
  });

  testWidgets('fast typing sends one request, not one per keystroke', (
    tester,
  ) async {
    final repository = await pumpList(tester, user: staffUser);
    final callsBefore = repository.listQueries.length;
    final search = find.byKey(const Key('vehicles.search'));

    for (final text in ['d', 'dh', 'dha', 'dhak', 'dhaka']) {
      await tester.enterText(search, text);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(repository.listQueries.length, callsBefore);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(repository.listQueries.length, callsBefore + 1);
    expect(repository.listQueries.last.search, 'dhaka');
    expect(repository.listQueries.last.page, 0);
  });

  testWidgets('Enter in the search field searches at once', (tester) async {
    final repository = await pumpList(tester, user: staffUser);

    await tester.enterText(find.byKey(const Key('vehicles.search')), 'dhk');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.listQueries.last.search, 'dhk');
  });

  testWidgets('tapping a column header sorts on the server', (tester) async {
    final repository = await pumpList(tester, user: staffUser);
    // The sort chip shows the same label, so target the table header.
    final header = find.descendant(
      of: find.byKey(const Key('vehicles.table')),
      matching: find.text('Vehicle number'),
    );

    await tester.tap(header);
    await tester.pumpAndSettle();
    expect(
      repository.listQueries.last.toQueryParameters()['sort'],
      'vehicleNumber,asc',
    );

    await tester.tap(header);
    await tester.pumpAndSettle();
    expect(
      repository.listQueries.last.toQueryParameters()['sort'],
      'vehicleNumber,desc',
    );
  });

  testWidgets('pagination asks the server for the next page', (tester) async {
    final repository = await pumpList(
      tester,
      user: staffUser,
      repository: FakeVehicleRepository(
        seed: [
          for (var id = 1; id <= 25; id++)
            testVehicle(id: id, vehicleNumber: 'DHK-${1000 + id}'),
        ],
      ),
    );
    expect(find.text('Page 1 of 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pagination.next')));
    await tester.pumpAndSettle();

    final parameters = repository.listQueries.last.toQueryParameters();
    expect(parameters['page'], 1);
    expect(parameters['size'], 20);
    expect(find.text('Page 2 of 2'), findsOneWidget);
    expect(find.text('DHK-1021'), findsOneWidget);
  });

  testWidgets('600-1024 px shows the compact table with brand/model', (
    tester,
  ) async {
    await pumpList(tester, user: staffUser, size: const Size(800, 900));

    expect(find.byKey(const Key('vehicles.table')), findsOneWidget);
    expect(find.text('Brand / model'), findsOneWidget);
    expect(find.text('Toyota Axio'), findsOneWidget);
    expect(find.text('Fuel'), findsNothing);
    expect(find.text('Added'), findsNothing);
  });

  testWidgets('wider than 1024 px shows the full table', (tester) async {
    await pumpList(tester, user: staffUser, size: const Size(1400, 900));

    expect(find.text('Fuel'), findsOneWidget);
    expect(find.text('Added'), findsOneWidget);
  });

  testWidgets('cancelling the delete dialog keeps the vehicle', (tester) async {
    final repository = await pumpList(tester, user: adminUser);

    await tester.tap(find.byKey(const ValueKey('vehicle.delete.1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm.cancel')));
    await tester.pumpAndSettle();

    expect(repository.vehicles.map((v) => v.id), [1, 2]);
    expect(find.text('DHK-1234'), findsOneWidget);
  });
}
