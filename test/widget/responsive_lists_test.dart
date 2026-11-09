import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/utils/clock.dart';
import 'package:stark_vms_frontend/features/assignments/data/assignment_repository.dart';
import 'package:stark_vms_frontend/features/assignments/presentation/assignment_history_view.dart';
import 'package:stark_vms_frontend/features/auth/presentation/auth_controller.dart';
import 'package:stark_vms_frontend/features/documents/data/document_repository.dart';
import 'package:stark_vms_frontend/features/documents/presentation/expiring_documents_screen.dart';
import 'package:stark_vms_frontend/features/maintenance/data/maintenance_repository.dart';
import 'package:stark_vms_frontend/features/maintenance/presentation/maintenance_tab.dart';

import '../helpers/fakes.dart';
import '../helpers/fakes_v2.dart';
import '../helpers/pump_app.dart';

/// Guideline 14.2 for the secondary lists: cards below 600 px, a compact
/// table from 600 to 1024 px, the full table above.
void main() {
  const phone = Size(360, 760);
  const tablet = Size(800, 900);
  const desktop = Size(1400, 1000);

  List<Override> overrides() => [
    clockProvider.overrideWithValue(FixedClock(DateTime(2026, 11, 18))),
    authControllerProvider.overrideWith(
      () => FakeAuthController(AuthState.signedIn(sessionFor(adminUser))),
    ),
    maintenanceRepositoryProvider.overrideWithValue(
      FakeMaintenanceRepository(
        seed: [testMaintenance(id: 1), testMaintenance(id: 2, cost: 9000)],
      ),
    ),
    documentRepositoryProvider.overrideWithValue(
      FakeDocumentRepository(seed: [testDocument(id: 31)]),
    ),
    assignmentRepositoryProvider.overrideWithValue(
      FakeAssignmentRepository(
        history: [
          testAssignment(id: 9),
          testAssignment(id: 8, driverId: 5, current: false),
        ],
      ),
    ),
  ];

  Future<void> pump(WidgetTester tester, Widget screen, Size size) {
    return pumpScreen(tester, screen, size: size, overrides: overrides());
  }

  group('maintenance history', () {
    const tab = Scaffold(body: MaintenanceTab(vehicleId: 12));

    testWidgets('cards on a phone', (tester) async {
      await pump(tester, tab, phone);
      expect(find.byKey(const ValueKey('maintenance.record.1')), findsOne);
      expect(find.byKey(const Key('maintenance.table')), findsNothing);
      expect(find.byKey(const ValueKey('maintenance.delete.1')), findsOne);
      expect(tester.takeException(), isNull);
    });

    testWidgets('compact table on a tablet', (tester) async {
      await pump(tester, tab, tablet);
      expect(find.byKey(const Key('maintenance.table')), findsOne);
      expect(find.byKey(const ValueKey('maintenance.record.1')), findsNothing);
      expect(find.text('Vendor'), findsOne);
      expect(find.text('Notes'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('full table on a desktop', (tester) async {
      await pump(tester, tab, desktop);
      expect(find.byKey(const Key('maintenance.table')), findsOne);
      expect(find.text('Notes'), findsOne);
      expect(find.text('Synthetic oil'), findsNWidgets(2));
      expect(find.byKey(const ValueKey('maintenance.audit.2')), findsOne);
      expect(find.byKey(const ValueKey('maintenance.edit.2')), findsOne);
      expect(tester.takeException(), isNull);
    });
  });

  group('expiring documents', () {
    const screen = ExpiringDocumentsScreen();

    testWidgets('cards on a phone', (tester) async {
      await pump(tester, screen, phone);
      expect(find.byKey(const ValueKey('expiring.document.31')), findsOne);
      expect(find.byKey(const Key('expiring.table')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('compact table on a tablet', (tester) async {
      await pump(tester, screen, tablet);
      expect(find.byKey(const Key('expiring.table')), findsOne);
      expect(find.text('Number'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('full table on a desktop; a row opens the vehicle', (
      tester,
    ) async {
      await pump(tester, screen, desktop);
      expect(find.byKey(const Key('expiring.table')), findsOne);
      expect(find.byKey(const ValueKey('expiring.document.31')), findsNothing);
      expect(find.text('Number'), findsOne);
      expect(find.text('TT-2026-0031'), findsOne);

      await tester.tap(find.text('DHK-1234'));
      await tester.pumpAndSettle();
      expect(
        find.text('Navigated to /vehicles/12?tab=documents'),
        findsOneWidget,
      );
    });
  });

  group('assignment history', () {
    const view = Scaffold(
      body: SingleChildScrollView(
        child: AssignmentHistoryView.forVehicle(vehicleId: 12),
      ),
    );

    testWidgets('cards on a phone', (tester) async {
      await pump(tester, view, phone);
      expect(find.byKey(const ValueKey('assignment.9')), findsOne);
      expect(find.byKey(const Key('assignments.table')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('compact table on a tablet', (tester) async {
      await pump(tester, view, tablet);
      expect(find.byKey(const Key('assignments.table')), findsOne);
      expect(find.text('Assigned by'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('full table on a desktop; a row opens the driver', (
      tester,
    ) async {
      await pump(tester, view, desktop);
      expect(find.byKey(const Key('assignments.table')), findsOne);
      expect(find.byKey(const ValueKey('assignment.9')), findsNothing);
      expect(find.text('Assigned by'), findsOne);
      expect(find.text('Current'), findsOne);
      expect(find.text('Ended'), findsOne);

      await tester.tap(find.text('Current'));
      await tester.pumpAndSettle();
      expect(find.text('Navigated to /drivers/4'), findsOneWidget);
    });
  });
}
