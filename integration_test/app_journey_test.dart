// End-to-end journey against a RUNNING backend (guideline section 15):
// login -> add vehicle -> duplicate blocked -> edit -> delete.
// The driver saves the README screenshots to docs/screenshots/.
//
// Run (see README):
//   chromedriver --port=4444
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_journey_test.dart \
//     -d web-server --browser-name=chrome --driver-port=4444 \
//     --dart-define=API_BASE_URL=http://localhost:8080/api/v1
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stark_vms_frontend/bootstrap.dart';

const String _adminEmail = String.fromEnvironment(
  'E2E_EMAIL',
  defaultValue: 'admin@stark.local',
);
const String _adminPassword = String.fromEnvironment(
  'E2E_PASSWORD',
  defaultValue: 'Admin@12345',
);

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

Future<void> chooseType(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('vehicleForm.type')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Saved by test_driver/integration_test.dart to docs/screenshots/.
  Future<void> screenshot(WidgetTester tester, String name) async {
    await settle(tester);
    await binding.takeScreenshot(name);
  }

  testWidgets('login, add, duplicate blocked, edit, delete', (tester) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    await bootstrap();

    final suffix = DateTime.now().millisecondsSinceEpoch.remainder(100000000);
    final number = 'E2E-$suffix';
    final sameNumberOtherFormat = 'e2e $suffix';

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
    await pumpUntilFound(
      tester,
      find.byKey(const Key('dashboard.totalVehicles')),
    );
    await screenshot(tester, 'dashboard');

    // FR-V02: register a vehicle.
    await tester.tap(find.byKey(const Key('dashboard.registerVehicle')));
    await pumpUntilFound(tester, find.byKey(const Key('vehicleForm.number')));
    await tester.enterText(find.byKey(const Key('vehicleForm.number')), number);
    await chooseType(tester, 'Car');
    await tester.enterText(
      find.byKey(const Key('vehicleForm.brand')),
      'Toyota',
    );
    await tester.tap(find.byKey(const Key('vehicleForm.save')));
    await pumpUntilFound(tester, find.byKey(const Key('vehicleDetail.number')));
    expect(find.text(number), findsWidgets);

    // FR-V05: the same number in another format is rejected with 409.
    await tester.tap(find.text('All vehicles'));
    await pumpUntilFound(tester, find.byKey(const Key('vehicles.table')));
    await screenshot(tester, 'vehicle_list');
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
    await screenshot(tester, 'vehicle_form_duplicate');
    await tester.tap(find.byKey(const Key('vehicleForm.cancel')));

    // FR-V03: edit the vehicle found through the server-side search.
    await pumpUntilFound(tester, find.byKey(const Key('vehicles.search')));
    await tester.enterText(find.byKey(const Key('vehicles.search')), number);
    // find.text would also match the search field's EditableText, so look
    // for the number as a plain Text in the result list.
    final resultNumber = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data == number,
    );
    await pumpUntilFound(tester, resultNumber);
    await tester.tap(resultNumber.first);
    await pumpUntilFound(tester, find.byKey(const Key('vehicleDetail.edit')));
    await tester.tap(find.byKey(const Key('vehicleDetail.edit')));
    await pumpUntilFound(tester, find.byKey(const Key('vehicleForm.model')));
    await tester.enterText(find.byKey(const Key('vehicleForm.model')), 'Axio');
    await tester.tap(find.byKey(const Key('vehicleForm.save')));
    await pumpUntilFound(tester, find.text('Toyota Axio'));

    // FR-V04: delete with confirmation (ADMIN).
    await tester.tap(find.byKey(const Key('vehicleDetail.delete')));
    await pumpUntilFound(tester, find.byKey(const Key('confirm.ok')));
    await tester.tap(find.byKey(const Key('confirm.ok')));
    await pumpUntilFound(tester, find.text('Vehicle $number deleted.'));
  });
}
