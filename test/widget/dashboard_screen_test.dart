import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/features/auth/presentation/auth_controller.dart';
import 'package:stark_vms_frontend/features/drivers/data/driver.dart';
import 'package:stark_vms_frontend/features/drivers/data/driver_query.dart';
import 'package:stark_vms_frontend/features/drivers/presentation/driver_providers.dart';
import 'package:stark_vms_frontend/features/dashboard/data/dashboard_repository.dart';
import 'package:stark_vms_frontend/features/dashboard/data/dashboard_summary.dart';
import 'package:stark_vms_frontend/features/dashboard/presentation/dashboard_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/fakes_v2.dart';
import '../helpers/pump_app.dart';

void main() {
  Future<FakeDashboardRepository> pumpDashboard(
    WidgetTester tester, {
    int failures = 0,
    Size size = const Size(1400, 1400),
  }) async {
    final repository = FakeDashboardRepository(
      summaryValue: DashboardSummary.fromJson(dashboardJson()),
      failuresLeft: failures,
    );
    await pumpScreen(
      tester,
      const DashboardScreen(),
      size: size,
      overrides: [
        dashboardRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(
          () => FakeAuthController(AuthState.signedIn(sessionFor(adminUser))),
        ),
      ],
    );
    return repository;
  }

  String statValue(WidgetTester tester, String cardKey) {
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byKey(Key(cardKey)),
        matching: find.byKey(const Key('stat.value')),
      ),
    );
    return text.data!;
  }

  testWidgets('renders the numbers from GET /dashboard/summary (FR-DB01)', (
    tester,
  ) async {
    final repository = await pumpDashboard(tester);

    expect(repository.calls, 1);
    expect(find.byKey(const Key('dashboard.welcome')), findsOneWidget);
    expect(statValue(tester, 'dashboard.vehicles.total'), '26');
    expect(statValue(tester, 'dashboard.vehicles.active'), '18');
    expect(statValue(tester, 'dashboard.vehicles.maintenance'), '5');
    expect(statValue(tester, 'dashboard.vehicles.inactive'), '3');
    expect(statValue(tester, 'dashboard.documents.expired'), '2');
    expect(statValue(tester, 'dashboard.documents.expiringSoon'), '4');
    expect(statValue(tester, 'dashboard.maintenance.month'), 'BDT 48,250.00');
    expect(find.text('7 records this month'), findsOneWidget);
    expect(statValue(tester, 'dashboard.drivers'), '12');
    expect(find.textContaining('9 assigned'), findsOneWidget);

    // Expiring lists with badges (FR-D02, FR-X02).
    expect(find.text('Expires in 12 days'), findsOneWidget);
    expect(find.text('Expired 3 days ago'), findsOneWidget);
    expect(find.text('Rahim Uddin'), findsOneWidget);
  });

  testWidgets('tapping a status card opens the filtered vehicle list', (
    tester,
  ) async {
    await pumpDashboard(tester);

    await tester.tap(find.byKey(const Key('dashboard.vehicles.maintenance')));
    await tester.pumpAndSettle();

    expect(
      find.text('Navigated to /vehicles?status=MAINTENANCE'),
      findsOneWidget,
    );
  });

  testWidgets('licence "View all" opens drivers sorted by licence expiry', (
    tester,
  ) async {
    await pumpDashboard(tester);
    final viewAll = find.descendant(
      of: find.byKey(const Key('dashboard.expiringLicenses')),
      matching: find.text('View all'),
    );
    await tester.ensureVisible(viewAll);
    await tester.tap(viewAll);
    await tester.pumpAndSettle();

    final navigated = find.text('Navigated to /drivers');
    expect(navigated, findsOneWidget);
    final query = ProviderScope.containerOf(tester.element(navigated))
        .read(driverQueryProvider);
    expect(query.sortField, DriverSortField.licenseExpiry);
    expect(query.sortDirection, SortDirection.ascending);
    expect(query.status, isNull);
    expect(query.search, isEmpty);
    expect(query.page, 0);
  });

  testWidgets('the drivers card clears driver filters', (tester) async {
    await pumpDashboard(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardScreen)),
    );
    container.read(driverQueryProvider.notifier)
      ..setStatus(DriverStatus.inactive)
      ..setSearch('karim');

    await tester.ensureVisible(find.byKey(const Key('dashboard.drivers')));
    await tester.tap(find.byKey(const Key('dashboard.drivers')));
    await tester.pumpAndSettle();

    expect(find.text('Navigated to /drivers'), findsOneWidget);
    final query = container.read(driverQueryProvider);
    expect(query.status, isNull);
    expect(query.search, isEmpty);
  });

  testWidgets('tapping the expired documents card opens the expiring screen', (
    tester,
  ) async {
    await pumpDashboard(tester);

    await tester.tap(find.byKey(const Key('dashboard.documents.expired')));
    await tester.pumpAndSettle();

    expect(
      find.text('Navigated to /documents/expiring?withinDays=30'),
      findsOneWidget,
    );
  });

  testWidgets('shows the error state and recovers with Retry', (tester) async {
    final repository = await pumpDashboard(tester, failures: 1);

    expect(find.text('Cannot reach the server.'), findsOneWidget);
    expect(find.byKey(const Key('error.retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('error.retry')));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(statValue(tester, 'dashboard.vehicles.total'), '26');
  });

  testWidgets('works on a phone-sized screen', (tester) async {
    await pumpDashboard(tester, size: const Size(390, 2400));

    expect(statValue(tester, 'dashboard.vehicles.total'), '26');
    expect(tester.takeException(), isNull);
  });
}
