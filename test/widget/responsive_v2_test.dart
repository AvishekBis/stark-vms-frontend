import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/network/api_exception.dart';
import 'package:stark_vms_frontend/core/utils/clock.dart';
import 'package:stark_vms_frontend/features/assignments/data/assignment_repository.dart';
import 'package:stark_vms_frontend/features/auth/presentation/auth_controller.dart';
import 'package:stark_vms_frontend/features/dashboard/data/dashboard_repository.dart';
import 'package:stark_vms_frontend/features/dashboard/data/dashboard_summary.dart';
import 'package:stark_vms_frontend/features/dashboard/presentation/dashboard_screen.dart';
import 'package:stark_vms_frontend/features/documents/data/document_repository.dart';
import 'package:stark_vms_frontend/features/documents/data/vehicle_document.dart';
import 'package:stark_vms_frontend/features/documents/presentation/expiring_documents_screen.dart';
import 'package:stark_vms_frontend/features/drivers/data/driver.dart';
import 'package:stark_vms_frontend/features/drivers/data/driver_repository.dart';
import 'package:stark_vms_frontend/features/drivers/presentation/driver_detail_screen.dart';
import 'package:stark_vms_frontend/features/drivers/presentation/drivers_list_screen.dart';
import 'package:stark_vms_frontend/features/maintenance/data/maintenance_record.dart';
import 'package:stark_vms_frontend/features/maintenance/data/maintenance_repository.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_repository.dart';
import 'package:stark_vms_frontend/features/vehicles/presentation/vehicle_detail_screen.dart';
import 'package:stark_vms_frontend/features/vehicles/presentation/vehicle_detail_tab.dart';
import 'package:stark_vms_frontend/features/vehicles/presentation/vehicle_list_screen.dart';
import 'package:stark_vms_frontend/shared/models/expiry_status.dart';
import 'package:stark_vms_frontend/features/users/data/user_repository.dart';
import 'package:stark_vms_frontend/features/users/presentation/user_form_screen.dart';
import 'package:stark_vms_frontend/features/users/presentation/users_list_screen.dart';
import 'package:stark_vms_frontend/shared/widgets/app_shell.dart';

import '../helpers/fakes.dart';
import '../helpers/fakes_users.dart';
import '../helpers/fakes_v2.dart';
import '../helpers/pump_app.dart';

/// Guideline 6 / 14.2: the v2.0 screens render without overflow from a
/// 360 px phone to a 1400 px desktop, inside the real app shell. Any
/// RenderFlex overflow is reported as a test failure.
void main() {
  const sizes = <String, Size>{
    'phone 360': Size(360, 760),
    'tablet 800': Size(800, 900),
    'desktop 1400': Size(1400, 1000),
  };

  /// Long, realistic values (Bangladeshi number plates, big costs).
  const longNumber = 'DHAKA METRO-GA 11-2345';

  Future<void> pumpInShell(
    WidgetTester tester,
    Widget screen, {
    required Size size,
    required String location,
    ApiException? assignError,
  }) async {
    final vehicles = FakeVehicleRepository(
      seed: [
        testVehicle(
          id: 12,
          vehicleNumber: longNumber,
          brand: 'Mitsubishi',
          model: 'Pajero Sport GLS',
          currentDriver: const DriverSummary(
            id: 4,
            fullName: 'Mohammad Abdur Rahim Uddin Chowdhury',
            phone: '01711000001',
          ),
        ),
      ],
    );
    await pumpScreen(
      tester,
      AppShell(location: location, child: screen),
      size: size,
      overrides: [
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 11, 18, 12))),
        vehicleRepositoryProvider.overrideWithValue(vehicles),
        dashboardRepositoryProvider.overrideWithValue(
          FakeDashboardRepository(
            summaryValue: DashboardSummary.fromJson({
              ...dashboardJson(),
              'maintenance': {
                'month': '2026-11',
                'count': 1234,
                'totalCost': 9999999999.99,
              },
            }),
          ),
        ),
        driverRepositoryProvider.overrideWithValue(
          FakeDriverRepository(
            seed: [
              testDriver(
                id: 4,
                fullName: 'Mohammad Abdur Rahim Uddin Chowdhury',
                licenseStatus: ExpiryStatus.expiringSoon,
                daysUntilLicenseExpiry: 12,
                currentVehicle: const VehicleSummary(
                  id: 12,
                  vehicleNumber: longNumber,
                ),
              ),
              testDriver(id: 5, fullName: 'Karim Mia', phone: '01811000002'),
            ],
          ),
        ),
        assignmentRepositoryProvider.overrideWithValue(
          FakeAssignmentRepository(
            assignError: assignError,
            history: [
              testAssignment(id: 9),
              testAssignment(id: 8, driverId: 5, current: false),
            ],
          ),
        ),
        documentRepositoryProvider.overrideWithValue(
          FakeDocumentRepository(
            seed: [
              testDocument(),
              testDocument(
                id: 32,
                type: DocumentType.fitnessCertificate,
                status: ExpiryStatus.expired,
                daysUntilExpiry: -120,
              ),
              testDocument(
                id: 33,
                type: DocumentType.routePermit,
                status: ExpiryStatus.valid,
                daysUntilExpiry: 300,
              ),
            ],
          ),
        ),
        maintenanceRepositoryProvider.overrideWithValue(
          FakeMaintenanceRepository(
            seed: [
              testMaintenance(cost: 9999999999.99),
              testMaintenance(id: 2, type: MaintenanceType.bodyWork),
            ],
          ),
        ),
        userRepositoryProvider.overrideWithValue(
          FakeUserRepository(
            seed: [
              adminAccount(),
              testUserAccount(
                email: 'mohammad.abdur.rahim.chowdhury@stark.local',
                fullName: 'Mohammad Abdur Rahim Uddin Chowdhury',
                enabled: false,
              ),
            ],
          ),
        ),
        authControllerProvider.overrideWith(
          () => FakeAuthController(AuthState.signedIn(sessionFor(adminUser))),
        ),
      ],
    );
  }

  for (final entry in sizes.entries) {
    final label = entry.key;
    final size = entry.value;

    testWidgets('dashboard has no overflow at $label', (tester) async {
      await pumpInShell(
        tester,
        const DashboardScreen(),
        size: size,
        location: '/dashboard',
      );
      expect(find.byKey(const Key('dashboard.vehicles.total')), findsOneWidget);
      expect(find.text('BDT 9,999,999,999.99'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final tab in VehicleDetailTab.values) {
      testWidgets('vehicle detail "${tab.label}" has no overflow at $label', (
        tester,
      ) async {
        await pumpInShell(
          tester,
          VehicleDetailScreen(vehicleId: 12, initialTab: tab),
          size: size,
          location: '/vehicles/12',
        );
        expect(find.byKey(const Key('vehicleDetail.number')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('vehicle list has no overflow at $label', (tester) async {
      await pumpInShell(
        tester,
        const VehicleListScreen(),
        size: size,
        location: '/vehicles',
      );
      expect(find.textContaining(longNumber), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('driver detail has no overflow at $label', (tester) async {
      await pumpInShell(
        tester,
        const DriverDetailScreen(driverId: 4),
        size: size,
        location: '/drivers/4',
      );
      expect(find.textContaining('Abdur Rahim'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('drivers list has no overflow at $label', (tester) async {
      await pumpInShell(
        tester,
        const DriversListScreen(),
        size: size,
        location: '/drivers',
      );
      expect(find.textContaining('Karim Mia'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('users list (v2.1) has no overflow at $label', (tester) async {
      await pumpInShell(
        tester,
        const UsersListScreen(),
        size: size,
        location: '/users',
      );
      expect(find.textContaining('Abdur Rahim'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('user edit form (v2.1) has no overflow at $label', (
      tester,
    ) async {
      await pumpInShell(
        tester,
        const UserFormScreen(userId: 7),
        size: size,
        location: '/users/7/edit',
      );
      expect(find.byKey(const Key('userForm.enabled')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('expiring documents have no overflow at $label', (
      tester,
    ) async {
      await pumpInShell(
        tester,
        const ExpiringDocumentsScreen(),
        size: size,
        location: '/documents/expiring',
      );
      expect(tester.takeException(), isNull);
    });
  }

  group('dialogs fit a 360 x 640 phone', () {
    const phone = Size(360, 640);

    testWidgets('assign driver dialog with a 409 error (TC-10)', (
      tester,
    ) async {
      await pumpInShell(
        tester,
        const VehicleDetailScreen(vehicleId: 12),
        size: phone,
        location: '/vehicles/12',
        assignError: problem(
          409,
          type: 'driver-already-assigned',
          title: 'Driver already assigned',
          detail:
              'Driver Karim Mia is already assigned to vehicle '
              'DHAKA METRO-GA 11-9999. Unassign them first.',
        ),
      );
      await tester.ensureVisible(
        find.byKey(const Key('vehicleDetail.assignDriver')),
      );
      await tester.tap(find.byKey(const Key('vehicleDetail.assignDriver')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('assignDialog.driver.5')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('assignDialog.driver.5')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('assignDialog.assign')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('assignDialog.error')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('status dialog with the INACTIVE warning', (tester) async {
      await pumpInShell(
        tester,
        const VehicleDetailScreen(vehicleId: 12),
        size: phone,
        location: '/vehicles/12',
      );
      await tester.ensureVisible(
        find.byKey(const Key('vehicleDetail.changeStatus')),
      );
      await tester.tap(find.byKey(const Key('vehicleDetail.changeStatus')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('statusDialog.INACTIVE')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('statusDialog.inactiveWarning')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('upload dialog with all validation errors', (tester) async {
      await pumpInShell(
        tester,
        const VehicleDetailScreen(
          vehicleId: 12,
          initialTab: VehicleDetailTab.documents,
        ),
        size: phone,
        location: '/vehicles/12',
      );
      await tester.tap(find.byKey(const Key('documents.upload')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('uploadDialog.submit')));
      await tester.pumpAndSettle();

      expect(find.text('Document type is required.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('maintenance dialog with all validation errors', (
      tester,
    ) async {
      await pumpInShell(
        tester,
        const VehicleDetailScreen(
          vehicleId: 12,
          initialTab: VehicleDetailTab.maintenance,
        ),
        size: phone,
        location: '/vehicles/12',
      );
      await tester.tap(find.byKey(const Key('maintenance.add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('maintenanceDialog.save')));
      await tester.pumpAndSettle();

      expect(find.text('Service date is required.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
