import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stark_vms_frontend/core/storage/preferences_provider.dart';
import 'package:stark_vms_frontend/features/auth/data/auth_models.dart';
import 'package:stark_vms_frontend/features/auth/data/auth_repository.dart';
import 'package:stark_vms_frontend/features/auth/presentation/auth_controller.dart';
import 'package:stark_vms_frontend/features/auth/presentation/change_password_dialog.dart';
import 'package:stark_vms_frontend/shared/widgets/app_shell.dart';

import '../helpers/fakes.dart';
import '../helpers/fakes_v2.dart';
import '../helpers/pump_app.dart';

/// v2.1 shell: "Users" for ADMIN only, and the user menu with
/// "Change password" for every role (contract 7.7).
void main() {
  late FakeAuthRepository auth;
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    auth = FakeAuthRepository(
      loginResponse: const LoginResponse(
        accessToken: 'test-token',
        tokenType: 'Bearer',
        expiresIn: Duration(hours: 1),
        user: staffUser,
      ),
    );
  });

  Future<ProviderContainer> pumpShell(
    WidgetTester tester,
    User user, {
    Size size = const Size(1400, 900),
  }) async {
    await pumpScreen(
      tester,
      const AppShell(location: '/dashboard', child: Text('content')),
      size: size,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        authRepositoryProvider.overrideWithValue(auth),
        authControllerProvider.overrideWith(
          () => FakeAuthController(AuthState.signedIn(sessionFor(user))),
        ),
      ],
    );
    return ProviderScope.containerOf(tester.element(find.text('content')));
  }

  Future<void> openChangePassword(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('shell.userMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shell.changePassword')));
    await tester.pumpAndSettle();
  }

  Future<void> fillPasswords(
    WidgetTester tester, {
    String current = 'Staff@12345',
    String next = 'N3w-Staff-Pass',
  }) async {
    await tester.enterText(
      find.byKey(const Key('changePassword.current')),
      current,
    );
    await tester.enterText(find.byKey(const Key('changePassword.new')), next);
    await tester.enterText(
      find.byKey(const Key('changePassword.confirm')),
      next,
    );
    await tester.tap(find.byKey(const Key('changePassword.save')));
    await tester.pumpAndSettle();
  }

  testWidgets('ADMIN sees "Users" in the navigation rail', (tester) async {
    await pumpShell(tester, adminUser);
    expect(find.text('Users'), findsOneWidget);
  });

  testWidgets('STAFF does not see "Users"', (tester) async {
    await pumpShell(tester, staffUser);
    expect(find.text('Users'), findsNothing);
    expect(find.text('Drivers'), findsOneWidget);
  });

  testWidgets('ADMIN sees "Users" in the phone drawer', (tester) async {
    await pumpShell(tester, adminUser, size: const Size(400, 900));
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Users'), findsOneWidget);
  });

  testWidgets('STAFF changes the own password and stays logged in', (
    tester,
  ) async {
    final container = await pumpShell(tester, staffUser);

    await openChangePassword(tester);
    expect(find.byKey(const Key('changePassword.dialog')), findsOneWidget);
    await fillPasswords(tester);

    expect(auth.passwordChanges.single, ('Staff@12345', 'N3w-Staff-Pass'));
    expect(auth.logins.single, ('staff@stark.local', 'N3w-Staff-Pass'));
    expect(find.byKey(const Key('changePassword.dialog')), findsNothing);
    expect(find.text(ChangePasswordDialog.successMessage), findsOneWidget);
    expect(
      container.read(authControllerProvider).requireValue.isAuthenticated,
      isTrue,
    );

    // Stops the session expiry timer the re-login started.
    await container.read(authControllerProvider.notifier).logout();
    await tester.pumpAndSettle();
  });

  testWidgets('a wrong current password shows under that field, no logout', (
    tester,
  ) async {
    const message = 'Current password is incorrect.';
    auth.changePasswordError = problem(
      400,
      type: 'validation',
      detail: message,
      errors: [
        {'field': 'currentPassword', 'message': message},
      ],
    );
    final container = await pumpShell(tester, staffUser);

    await openChangePassword(tester);
    await fillPasswords(tester, current: 'wrong-password');

    expect(
      find.descendant(
        of: find.byKey(const Key('changePassword.current')),
        matching: find.text(message),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('changePassword.dialog')), findsOneWidget);
    expect(auth.logins, isEmpty);
    expect(
      container.read(authControllerProvider).requireValue.isAuthenticated,
      isTrue,
    );
  });

  testWidgets('429 after too many wrong current passwords shows the server '
      'detail and keeps the session', (tester) async {
    const detail = 'Too many failed login attempts. Try again in 15 minutes.';
    auth.changePasswordError = problem(
      429,
      type: 'too-many-login-attempts',
      detail: detail,
    );
    final container = await pumpShell(tester, staffUser);

    await openChangePassword(tester);
    await fillPasswords(tester);

    expect(find.byKey(const Key('changePassword.error')), findsOneWidget);
    expect(find.text(detail), findsOneWidget);
    expect(find.byKey(const Key('changePassword.dialog')), findsOneWidget);
    expect(auth.logins, isEmpty);
    expect(
      container.read(authControllerProvider).requireValue.isAuthenticated,
      isTrue,
    );
  });

  testWidgets('client-side checks: policy, repeat, different from current', (
    tester,
  ) async {
    await pumpShell(tester, staffUser);
    await openChangePassword(tester);

    await fillPasswords(tester, next: 'short');
    expect(find.text('Password must be at least 8 characters.'), findsOne);

    await fillPasswords(tester, current: 'Same-Pass-1', next: 'Same-Pass-1');
    expect(
      find.text('The new password must be different from the current one.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('changePassword.new')),
      'N3w-Staff-Pass',
    );
    await tester.enterText(
      find.byKey(const Key('changePassword.confirm')),
      'Other-Pass-2',
    );
    await tester.tap(find.byKey(const Key('changePassword.save')));
    await tester.pumpAndSettle();
    expect(find.text('The passwords do not match.'), findsOneWidget);
    expect(auth.passwordChanges, isEmpty);
  });

  testWidgets('"Log out" is in the user menu', (tester) async {
    final container = await pumpShell(tester, adminUser);

    await tester.tap(find.byKey(const Key('shell.userMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shell.logout')));
    await tester.pumpAndSettle();

    final state = container.read(authControllerProvider).requireValue;
    expect(state.isAuthenticated, isFalse);
    expect(state.notice, AuthState.loggedOutNotice);
  });
}
