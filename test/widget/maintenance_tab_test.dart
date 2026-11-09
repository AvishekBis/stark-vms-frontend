import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/utils/clock.dart';
import 'package:stark_vms_frontend/features/auth/data/auth_models.dart';
import 'package:stark_vms_frontend/features/auth/presentation/auth_controller.dart';
import 'package:stark_vms_frontend/features/maintenance/data/maintenance_repository.dart';
import 'package:stark_vms_frontend/features/maintenance/presentation/maintenance_tab.dart';

import '../helpers/fakes.dart';
import '../helpers/fakes_v2.dart';
import '../helpers/pump_app.dart';

void main() {
  Future<FakeMaintenanceRepository> pumpTab(
    WidgetTester tester, {
    required User user,
    FakeMaintenanceRepository? repository,
  }) async {
    final repo =
        repository ??
        FakeMaintenanceRepository(
          seed: [
            testMaintenance(id: 1, cost: 3500),
            testMaintenance(id: 2, cost: 9000),
          ],
          totalCost: 12500,
        );
    await pumpScreen(
      tester,
      const Scaffold(body: MaintenanceTab(vehicleId: 12)),
      overrides: [
        maintenanceRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 11, 18))),
        authControllerProvider.overrideWith(
          () => FakeAuthController(AuthState.signedIn(sessionFor(user))),
        ),
      ],
    );
    return repo;
  }

  testWidgets('shows the total cost and record count (FR-M02)', (tester) async {
    await pumpTab(tester, user: staffUser);

    expect(find.text('Total cost BDT 12,500.00'), findsOneWidget);
    expect(find.text('2 records in total'), findsOneWidget);
    expect(find.text('BDT 3,500.00'), findsOneWidget);
    expect(find.text('BDT 9,000.00'), findsOneWidget);
    // FR-X01: who added each record.
    expect(find.byKey(const ValueKey('maintenance.audit.1')), findsOneWidget);
    expect(find.textContaining('by staff@stark.local'), findsWidgets);
  });

  testWidgets('STAFF can edit but not delete; ADMIN can delete', (
    tester,
  ) async {
    await pumpTab(tester, user: staffUser);
    expect(find.byKey(const ValueKey('maintenance.edit.1')), findsOneWidget);
    expect(find.byKey(const ValueKey('maintenance.delete.1')), findsNothing);
  });

  testWidgets('ADMIN delete confirms and refreshes the total', (tester) async {
    final repository = await pumpTab(
      tester,
      user: adminUser,
      repository: FakeMaintenanceRepository(
        seed: [
          testMaintenance(id: 1, cost: 3500),
          testMaintenance(id: 2, cost: 9000),
        ],
      ),
    );

    // The full table may be wider than the window; it scrolls sideways.
    await tester.ensureVisible(
      find.byKey(const ValueKey('maintenance.delete.2')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('maintenance.delete.2')));
    await tester.pumpAndSettle();
    expect(find.text('Delete maintenance record?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm.ok')));
    await tester.pumpAndSettle();

    expect(repository.records.map((r) => r.id), [1]);
    expect(find.text('Total cost BDT 3,500.00'), findsOneWidget);
  });

  testWidgets('add dialog validates cost and required fields', (tester) async {
    final repository = await pumpTab(tester, user: staffUser);

    await tester.tap(find.byKey(const Key('maintenance.add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('maintenanceDialog.cost')),
      '10.123',
    );
    await tester.tap(find.byKey(const Key('maintenanceDialog.save')));
    await tester.pumpAndSettle();

    expect(find.text('Service date is required.'), findsOneWidget);
    expect(find.text('Maintenance type is required.'), findsOneWidget);
    expect(
      find.text(
        'Enter the cost as a number with up to 2 decimals, e.g. 3500.00.',
      ),
      findsOneWidget,
    );
    expect(repository.saved, isEmpty);
  });

  testWidgets('empty state', (tester) async {
    await pumpTab(
      tester,
      user: staffUser,
      repository: FakeMaintenanceRepository(),
    );
    expect(find.text('No maintenance recorded yet'), findsOneWidget);
    expect(find.text('Total cost BDT 0.00'), findsOneWidget);
  });
}
