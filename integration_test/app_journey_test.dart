// End-to-end journeys against a RUNNING backend (guideline section 15).
//
// v1.0: login -> add vehicle -> duplicate blocked -> edit -> delete.
// v2.0: add vehicle -> upload document -> expiry badge visible ->
//       dashboard counts it and lists it with the same badge ->
//       delete blocked by history (BR-10) ->
//       delete document -> delete vehicle.
// v2.1: the vehicle edit above sends the loaded `version` (ADR 0023) ->
//       ADMIN opens Users -> adds a STAFF user with a unique e-mail ->
//       finds it in the list -> disables it (confirmation; the PUT sends
//       the user's `version`) -> the list shows "Disabled".
//
// Also saves the README screenshots (docs/screenshots/, through
// test_driver/integration_test.dart).
//
// Run (see README):
//   chromedriver --port=4444
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_journey_test.dart -d web-server \
//     --browser-name=chrome --driver-port=4444 \
//     --dart-define=API_BASE_URL=http://localhost:8080/api/v1
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stark_vms_frontend/bootstrap.dart';
import 'package:stark_vms_frontend/features/documents/data/document_file_picker.dart';
import 'package:stark_vms_frontend/features/documents/data/vehicle_document.dart';
import 'package:stark_vms_frontend/features/documents/presentation/expiring_documents_screen.dart';
import 'package:stark_vms_frontend/shared/models/expiry_status.dart';
import 'package:stark_vms_frontend/shared/widgets/expiry_badge.dart';

const String _adminEmail = String.fromEnvironment(
  'E2E_EMAIL',
  defaultValue: 'admin@stark.local',
);
const String _adminPassword = String.fromEnvironment(
  'E2E_PASSWORD',
  defaultValue: 'Admin@12345',
);

/// Seeded (local profile) ACTIVE car with maintenance records.
const String _demoVehicle = 'DHAKA METRO-GA 11-2345';

/// The browser's file dialog cannot be driven by a test, so the journey
/// "picks" a tiny real PDF (it starts with the `%PDF` magic bytes).
class _TinyPdfPicker implements DocumentFilePicker {
  @override
  Future<PickedFile?> pick() async {
    final bytes = Uint8List.fromList(
      utf8.encode('%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n'),
    );
    return PickedFile(
      name: 'e2e-tax-token.pdf',
      size: bytes.length,
      bytes: bytes,
    );
  }
}

/// Pumps frames until [finder] matches or [timeout] passes (real network),
/// then lets route transitions finish so the next action hits a settled
/// screen (typing into a field while its page is still animating in can be
/// lost on web).
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 90),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) {
      await settle(tester);
      return;
    }
  }
  throw TestFailure(
    'Timed out waiting for $finder\nVisible texts: ${_visibleTexts()}',
  );
}

/// Like `pumpAndSettle`, but gives up quietly after [timeout] instead of
/// throwing, because a loading spinner can keep scheduling frames.
Future<void> settle(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  do {
    await tester.pump(const Duration(milliseconds: 100));
  } while (tester.binding.hasScheduledFrame &&
      DateTime.now().isBefore(deadline));
}

/// Text currently on screen, to make a timeout failure self-explaining.
List<String> _visibleTexts() => find
    .byType(Text)
    .evaluate()
    .map((element) => (element.widget as Text).data ?? '')
    .where((text) => text.isNotEmpty)
    .toList();

/// Pumps frames until [finder] matches nothing (e.g. a SnackBar timed out).
Future<void> pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isNotEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Timed out waiting for $finder to disappear');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// A plain [Text] showing exactly [data] - unlike `find.text`, it does not
/// match the search field the same text was typed into.
Finder plainText(String data) =>
    find.byWidgetPredicate((widget) => widget is Text && widget.data == data);

/// Taps a main navigation destination (NavigationRail on wide screens).
Future<void> navigateTo(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationRail),
      matching: find.text(label),
    ),
  );
  await settle(tester);
}

/// Picks [option] in the FilterMenu chip with [key].
Future<void> chooseFilter(WidgetTester tester, Key key, String option) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> chooseType(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('vehicleForm.type')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Finder statValue(String cardKey) => find.descendant(
  of: find.byKey(Key(cardKey)),
  matching: find.byKey(const Key('stat.value')),
);

int readStat(WidgetTester tester, String cardKey) {
  final text = tester.widget<Text>(statValue(cardKey)).data ?? '0';
  return int.parse(text.replaceAll(',', ''));
}

/// The badge text of a document uploaded with "today" as its expiry date:
/// "Expires today" (EXPIRING_SOON, 0 days). The neighbours are accepted only
/// because the date picker uses the browser's date while the server decides
/// "today" in Asia/Dhaka, which can differ around midnight.
const Set<String> _expiresTodayTexts = {
  'Expires today',
  'Expires tomorrow',
  'Expired yesterday',
};

/// Checks the single [ExpiryBadge] under [scope]: an EXPIRING_SOON (or,
/// around midnight, EXPIRED) badge whose text is one of
/// [_expiresTodayTexts] and is actually shown. Returns the text.
String expectExpiresTodayBadge(WidgetTester tester, Finder scope) {
  final badgeFinder = find.descendant(
    of: scope,
    matching: find.byType(ExpiryBadge),
  );
  expect(badgeFinder, findsOneWidget);
  final badge = tester.widget<ExpiryBadge>(badgeFinder);
  expect(badge.status, isIn([ExpiryStatus.expiringSoon, ExpiryStatus.expired]));
  final text = badge.status.describe(badge.daysUntilExpiry);
  expect(text, isIn(_expiresTodayTexts));
  expect(
    find.descendant(of: badgeFinder, matching: find.text(text)),
    findsOneWidget,
  );
  return text;
}

Future<void> registerVehicle(WidgetTester tester, String number) async {
  await tester.enterText(find.byKey(const Key('vehicleForm.number')), number);
  await chooseType(tester, 'Car');
  await tester.enterText(find.byKey(const Key('vehicleForm.brand')), 'Toyota');
  await tester.tap(find.byKey(const Key('vehicleForm.save')));
  await pumpUntilFound(tester, find.byKey(const Key('vehicleDetail.number')));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Saved by test_driver/integration_test.dart to docs/screenshots/.
  Future<void> screenshot(WidgetTester tester, String name) async {
    await settle(tester);
    await binding.takeScreenshot(name);
  }

  testWidgets('v1 + v2 journey', (tester) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    await bootstrap(
      overrides: [
        documentFilePickerProvider.overrideWithValue(_TinyPdfPicker()),
      ],
    );

    final suffix = DateTime.now().millisecondsSinceEpoch.remainder(100000000);
    final number = 'E2E-$suffix';
    final sameNumberOtherFormat = 'e2e $suffix';
    final documentVehicle = 'E2E-DOC-$suffix';

    // FR-AUTH-01: login.
    await pumpUntilFound(tester, find.byKey(const Key('login.email')));
    await screenshot(tester, 'login');
    await tester.enterText(find.byKey(const Key('login.email')), _adminEmail);
    await tester.enterText(
      find.byKey(const Key('login.password')),
      _adminPassword,
    );
    await tester.tap(find.byKey(const Key('login.submit')));
    await pumpUntilFound(tester, find.byKey(const Key('dashboard.welcome')));
    await pumpUntilFound(tester, statValue('dashboard.vehicles.total'));
    await screenshot(tester, 'dashboard');

    // FR-V02: register a vehicle.
    await tester.tap(find.byKey(const Key('dashboard.registerVehicle')));
    await pumpUntilFound(tester, find.byKey(const Key('vehicleForm.number')));
    await registerVehicle(tester, number);
    expect(find.text(number), findsWidgets);

    // FR-V05: the same number in another format is rejected with 409.
    await tester.tap(find.text('All vehicles'));
    await pumpUntilFound(tester, find.byKey(const Key('vehicles.register')));
    await tester.tap(find.byKey(const Key('vehicles.register')));
    await pumpUntilFound(tester, find.byKey(const Key('vehicleForm.number')));
    await tester.enterText(
      find.byKey(const Key('vehicleForm.number')),
      sameNumberOtherFormat,
    );
    await chooseType(tester, 'Car');
    await tester.tap(find.byKey(const Key('vehicleForm.save')));
    await pumpUntilFound(
      tester,
      find.descendant(
        of: find.byKey(const Key('vehicleForm.number')),
        matching: find.textContaining('already registered'),
      ),
    );
    await tester.tap(find.byKey(const Key('vehicleForm.cancel')));

    // FR-V03 / FR-V08: edit the vehicle found through the server search.
    await pumpUntilFound(tester, find.byKey(const Key('vehicles.search')));
    await tester.enterText(find.byKey(const Key('vehicles.search')), number);
    await pumpUntilFound(tester, plainText(number));
    await tester.tap(plainText(number).first);
    await pumpUntilFound(tester, find.byKey(const Key('vehicleDetail.edit')));
    await tester.tap(find.byKey(const Key('vehicleDetail.edit')));
    await pumpUntilFound(tester, find.byKey(const Key('vehicleForm.model')));
    await tester.enterText(find.byKey(const Key('vehicleForm.model')), 'Axio');
    await tester.tap(find.byKey(const Key('vehicleForm.save')));
    await pumpUntilFound(tester, find.text('Toyota Axio'));

    // FR-V04: delete with confirmation (ADMIN); no history, so 204.
    await tester.tap(find.byKey(const Key('vehicleDetail.delete')));
    await pumpUntilFound(tester, find.byKey(const Key('confirm.ok')));
    await tester.tap(find.byKey(const Key('confirm.ok')));
    await pumpUntilFound(tester, find.text('Vehicle $number deleted.'));

    // ---- v2.0 ----
    // FR-DB01: remember the "expiring soon" count.
    await tester.tap(find.text('Dashboard').first);
    await pumpUntilFound(tester, statValue('dashboard.documents.expiringSoon'));
    // Expired + expiring: robust even if the browser's date differs from
    // "today" in Asia/Dhaka around midnight.
    int attention() =>
        readStat(tester, 'dashboard.documents.expired') +
        readStat(tester, 'dashboard.documents.expiringSoon');
    final attentionBefore = attention();

    // A second vehicle for the document journey.
    await tester.tap(find.byKey(const Key('dashboard.registerVehicle')));
    await pumpUntilFound(tester, find.byKey(const Key('vehicleForm.number')));
    await registerVehicle(tester, documentVehicle);

    // FR-D01: upload a document that expires today.
    await tester.tap(find.byKey(const Key('vehicleDetail.tab.documents')));
    await pumpUntilFound(tester, find.byKey(const Key('documents.upload')));
    await tester.tap(find.byKey(const Key('documents.upload')));
    await pumpUntilFound(tester, find.byKey(const Key('uploadDialog.type')));
    await tester.tap(find.byKey(const Key('uploadDialog.type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tax token').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('uploadDialog.number')),
      'TT-$suffix',
    );
    await tester.tap(find.byKey(const Key('uploadDialog.expiryDate')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // the date picker opens on today
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('uploadDialog.pickFile')));
    await pumpUntilFound(tester, find.textContaining('e2e-tax-token.pdf'));
    await tester.tap(find.byKey(const Key('uploadDialog.submit')));

    // FR-D02: the EXPIRING_SOON badge is visible in the Documents tab
    // (the ExpiryBadge itself, not the "Expires" column header).
    await pumpUntilFound(tester, find.text('1 document'));
    await pumpUntilFound(tester, find.byType(ExpiryBadge));
    final badgeText = expectExpiresTodayBadge(tester, find.byType(TabBarView));
    await screenshot(tester, 'vehicle_documents');

    // FR-DB01: the dashboard counts it ...
    await tester.tap(find.text('Dashboard').first);
    await pumpUntilFound(tester, statValue('dashboard.documents.expiringSoon'));
    expect(attention(), attentionBefore + 1);

    // ... and lists it under "Expiring documents" with the same badge.
    final dashboardDocument = find.ancestor(
      of: find.descendant(
        of: find.byKey(const Key('dashboard.expiringDocuments')),
        matching: find.textContaining(documentVehicle),
      ),
      matching: find.byType(ExpiringDocumentTile),
    );
    await pumpUntilFound(tester, dashboardDocument);
    await tester.ensureVisible(dashboardDocument);
    await settle(tester);
    expect(dashboardDocument, findsOneWidget);
    expect(expectExpiresTodayBadge(tester, dashboardDocument), badgeText);

    // The expiring documents screen lists it too.
    await tester.ensureVisible(
      find.byKey(const Key('dashboard.documents.expiringSoon')),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('dashboard.documents.expiringSoon')));
    await pumpUntilFound(tester, find.byKey(const Key('expiring.withinDays')));
    await pumpUntilFound(tester, find.textContaining(documentVehicle));
    await tester.tap(find.textContaining(documentVehicle).first);

    // BR-10: a vehicle with a document cannot be deleted.
    await pumpUntilFound(tester, find.byKey(const Key('documents.upload')));
    await tester.tap(find.byKey(const Key('vehicleDetail.tab.overview')));
    await pumpUntilFound(tester, find.byKey(const Key('vehicleDetail.delete')));

    // FR-DR02: the assign dialog offers available drivers (cancelled here).
    await tester.tap(find.byKey(const Key('vehicleDetail.assignDriver')));
    await pumpUntilFound(tester, find.byKey(const Key('assignDialog')));
    await pumpUntilFound(
      tester,
      find.byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> &&
            key.value.startsWith('assignDialog.driver.');
      }),
    );
    await screenshot(tester, 'assign_driver');
    await tester.tap(find.byKey(const Key('assignDialog.cancel')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('vehicleDetail.delete')));
    await pumpUntilFound(tester, find.byKey(const Key('confirm.ok')));
    await tester.tap(find.byKey(const Key('confirm.ok')));
    await pumpUntilFound(tester, find.byKey(const Key('vehicleHistoryDialog')));
    await tester.tap(find.byKey(const Key('vehicleHistoryDialog.close')));
    await tester.pumpAndSettle();

    // Clean up: delete the document (ADMIN), then the vehicle.
    await tester.tap(find.byKey(const Key('vehicleDetail.tab.documents')));
    final deleteDocument = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith('document.delete.');
    });
    await pumpUntilFound(tester, deleteDocument);
    await tester.tap(deleteDocument.first);
    await pumpUntilFound(tester, find.byKey(const Key('confirm.ok')));
    await tester.tap(find.byKey(const Key('confirm.ok')));
    await pumpUntilFound(tester, find.text('No documents yet'));
    await tester.tap(find.byKey(const Key('vehicleDetail.tab.overview')));
    await pumpUntilFound(tester, find.byKey(const Key('vehicleDetail.delete')));
    await tester.tap(find.byKey(const Key('vehicleDetail.delete')));
    await pumpUntilFound(tester, find.byKey(const Key('confirm.ok')));
    await tester.tap(find.byKey(const Key('confirm.ok')));
    await pumpUntilFound(
      tester,
      find.text('Vehicle $documentVehicle deleted.'),
    );

    // ---- Read-only tour of the seeded demo data, for the README ----
    // FR-DR01: drivers list.
    await navigateTo(tester, 'Drivers');
    await pumpUntilFound(tester, find.byKey(const Key('drivers.table')));
    await pumpUntilGone(tester, find.byType(SnackBar)); // "Vehicle … deleted."
    await screenshot(tester, 'drivers_list');

    // FR-V09: vehicle list with status and type filters.
    await navigateTo(tester, 'Vehicles');
    await pumpUntilFound(tester, find.byKey(const Key('vehicles.search')));
    await tester.enterText(find.byKey(const Key('vehicles.search')), '');
    await chooseFilter(tester, const Key('vehicles.statusFilter'), 'Active');
    await chooseFilter(tester, const Key('vehicles.typeFilter'), 'Car');
    await pumpUntilFound(tester, find.text('Status: Active'));
    await pumpUntilFound(tester, plainText(_demoVehicle));
    await screenshot(tester, 'vehicle_list_filters');

    // FR-M02: maintenance tab with the total cost.
    await tester.tap(plainText(_demoVehicle).first);
    await pumpUntilFound(
      tester,
      find.byKey(const Key('vehicleDetail.tab.maintenance')),
    );
    await tester.tap(find.byKey(const Key('vehicleDetail.tab.maintenance')));
    await pumpUntilFound(
      tester,
      find.byKey(const Key('maintenance.recordCount')),
    );
    await screenshot(tester, 'vehicle_maintenance');

    // ---- v2.1: ADMIN user management (ADR 0024) ----
    // Users cannot be deleted (audit columns refer to them), so the journey
    // disables the account it creates at the end.
    final userEmail = 'e2e-$suffix@stark.local';
    final userPassword = 'E2e-Pass-$suffix';
    await navigateTo(tester, 'Users');
    await pumpUntilFound(tester, find.byKey(const Key('users.table')));
    await tester.tap(find.byKey(const Key('users.add')));
    await pumpUntilFound(tester, find.byKey(const Key('userForm.email')));
    await tester.enterText(find.byKey(const Key('userForm.email')), userEmail);
    await tester.enterText(
      find.byKey(const Key('userForm.fullName')),
      'E2E Officer $suffix',
    );
    await tester.enterText(
      find.byKey(const Key('userForm.password')),
      userPassword,
    );
    await tester.enterText(
      find.byKey(const Key('userForm.confirmPassword')),
      userPassword,
    );
    await tester.tap(find.byKey(const Key('userForm.save')));
    await pumpUntilFound(tester, find.text('User $userEmail added.'));

    // The new account is in the list (default role STAFF, enabled).
    await pumpUntilFound(tester, find.byKey(const Key('users.table')));
    await pumpUntilGone(tester, find.byType(SnackBar));
    await screenshot(tester, 'users_list');
    await tester.enterText(find.byKey(const Key('users.search')), userEmail);
    await pumpUntilFound(tester, plainText(userEmail));
    await pumpUntilFound(tester, find.text('Enabled'));
    expect(find.text('Staff'), findsWidgets);

    // Disable it: the edit form sends the loaded version, and disabling
    // needs a confirmation.
    await tester.tap(plainText(userEmail).first);
    await pumpUntilFound(tester, find.byKey(const Key('userForm.enabled')));
    await tester.tap(find.byKey(const Key('userForm.enabled')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('userForm.save')));
    await pumpUntilFound(tester, find.byKey(const Key('confirm.ok')));
    await tester.tap(find.byKey(const Key('confirm.ok')));
    await pumpUntilFound(tester, find.text('User $userEmail updated.'));
    await pumpUntilFound(tester, find.byKey(const Key('users.search')));
    await tester.enterText(find.byKey(const Key('users.search')), userEmail);
    await pumpUntilFound(tester, find.text('Disabled'));
  });
}
