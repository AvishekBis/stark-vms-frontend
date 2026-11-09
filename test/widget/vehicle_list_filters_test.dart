import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/features/auth/presentation/auth_controller.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_enums.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_repository.dart';
import 'package:stark_vms_frontend/features/vehicles/presentation/vehicle_list_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

void main() {
  FakeVehicleRepository seeded() => FakeVehicleRepository(
    seed: [
      testVehicle(
        id: 1,
        vehicleNumber: 'DHK-1234',
        currentDriver: const DriverSummary(id: 4, fullName: 'Rahim Uddin'),
      ),
      testVehicle(
        id: 2,
        vehicleNumber: 'DHK-2000',
        vehicleType: VehicleType.bus,
        status: VehicleStatus.maintenance,
      ),
      for (var id = 3; id <= 30; id++)
        testVehicle(id: id, vehicleNumber: 'DHK-${3000 + id}'),
    ],
  );

  Future<FakeVehicleRepository> pumpList(
    WidgetTester tester, {
    Widget screen = const VehicleListScreen(),
    Size size = const Size(1400, 1000),
  }) async {
    final repository = seeded();
    await pumpScreen(
      tester,
      screen,
      size: size,
      overrides: [
        vehicleRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(
          () => FakeAuthController(AuthState.signedIn(sessionFor(staffUser))),
        ),
      ],
    );
    return repository;
  }

  Future<void> choose(
    WidgetTester tester,
    String filterKey,
    String label,
  ) async {
    await tester.tap(find.byKey(Key(filterKey)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('status and type filters are sent to the server (FR-V09)', (
    tester,
  ) async {
    final repository = await pumpList(tester);

    await choose(tester, 'vehicles.statusFilter', 'Maintenance');
    var parameters = repository.listQueries.last.toQueryParameters();
    expect(parameters['status'], 'MAINTENANCE');
    expect(find.text('Status: Maintenance'), findsOneWidget);
    expect(find.text('DHK-2000'), findsOneWidget);
    expect(find.text('DHK-1234'), findsNothing);

    await choose(tester, 'vehicles.typeFilter', 'Bus');
    parameters = repository.listQueries.last.toQueryParameters();
    expect(parameters['status'], 'MAINTENANCE');
    expect(parameters['type'], 'BUS');

    await choose(tester, 'vehicles.statusFilter', 'All');
    parameters = repository.listQueries.last.toQueryParameters();
    expect(parameters.containsKey('status'), isFalse);
    expect(parameters['type'], 'BUS');
  });

  testWidgets('search is sent with the filters (FR-V08)', (tester) async {
    final repository = await pumpList(tester);

    await choose(tester, 'vehicles.statusFilter', 'Active');
    await tester.enterText(find.byKey(const Key('vehicles.search')), 'rahim');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    final parameters = repository.listQueries.last.toQueryParameters();
    expect(parameters['search'], 'rahim');
    expect(parameters['status'], 'ACTIVE');
    expect(find.text('Search number, brand, model or driver'), findsOneWidget);
  });

  testWidgets('changing a filter goes back to page 1', (tester) async {
    final repository = await pumpList(tester);

    await tester.tap(find.byKey(const Key('pagination.next')));
    await tester.pumpAndSettle();
    expect(repository.listQueries.last.page, 1);

    await choose(tester, 'vehicles.typeFilter', 'Car');
    expect(repository.listQueries.last.page, 0);
    expect(repository.listQueries.last.type, VehicleType.car);
  });

  testWidgets('shows the current driver in the table and on cards', (
    tester,
  ) async {
    await pumpList(tester);
    expect(find.text('Driver'), findsOneWidget);
    expect(find.text('Rahim Uddin'), findsOneWidget);
  });

  testWidgets('cards show the driver line on phones', (tester) async {
    await pumpList(tester, size: const Size(400, 900));
    expect(find.byKey(const ValueKey('vehicle.card.driver.1')), findsOneWidget);
    expect(find.text('Driver: Rahim Uddin'), findsOneWidget);
  });

  testWidgets('/vehicles?status=INACTIVE applies the filter from the URL', (
    tester,
  ) async {
    final repository = await pumpList(
      tester,
      // Like the real shell: the list is only shown once signed in.
      screen: Consumer(
        builder: (context, ref, _) => ref.watch(currentUserProvider) == null
            ? const SizedBox.shrink()
            : const VehicleListScreen(
                hasRouteFilters: true,
                routeStatus: VehicleStatus.inactive,
              ),
      ),
    );

    expect(repository.listQueries.last.status, VehicleStatus.inactive);
    expect(find.text('No vehicles match the filters'), findsOneWidget);
  });
}
