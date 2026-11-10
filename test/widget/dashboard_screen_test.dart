import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/features/auth/presentation/auth_controller.dart';
import 'package:stark_vms_frontend/features/dashboard/presentation/dashboard_screen.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_repository.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

/// The v1.0 dashboard: the vehicle count and the newest vehicles.
void main() {
  Future<void> pumpDashboard(WidgetTester tester, {required Size size}) async {
    await pumpScreen(
      tester,
      const DashboardScreen(),
      size: size,
      overrides: [
        vehicleRepositoryProvider.overrideWithValue(
          FakeVehicleRepository(
            seed: [
              for (var id = 1; id <= 6; id++)
                testVehicle(id: id, vehicleNumber: 'DHK-${1000 + id}'),
            ],
          ),
        ),
        authControllerProvider.overrideWith(
          () => FakeAuthController(AuthState.signedIn(sessionFor(adminUser))),
        ),
      ],
    );
  }

  /// Every "recent vehicle" row, whatever its id (the fake does not sort).
  final recentRows = find.byWidgetPredicate(
    (widget) =>
        widget is ListTile &&
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith('dashboard.recent.'),
  );

  for (final (label, size) in const [
    ('phone 400', Size(400, 900)),
    ('desktop 1400', Size(1400, 1000)),
  ]) {
    // A ListTile inside a painted card reports "ink splashes may be invisible"
    // in debug mode. The browser journey caught that once; check it here too.
    testWidgets(
      'shows five recent vehicles without framework errors at $label',
      (tester) async {
        await pumpDashboard(tester, size: size);
        // The dashboard is a lazy ListView: on a phone the panel starts below
        // the fold and is only built once it scrolls into view.
        await tester.scrollUntilVisible(recentRows.first, 300);
        await tester.pumpAndSettle();

        expect(recentRows, findsNWidgets(5));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
