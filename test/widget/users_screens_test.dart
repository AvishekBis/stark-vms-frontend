import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/config/app_config.dart';
import 'package:stark_vms_frontend/features/auth/data/auth_models.dart';
import 'package:stark_vms_frontend/features/auth/presentation/auth_controller.dart';
import 'package:stark_vms_frontend/features/users/data/user_repository.dart';
import 'package:stark_vms_frontend/features/users/presentation/user_form_screen.dart';
import 'package:stark_vms_frontend/features/users/presentation/users_list_screen.dart';
import 'package:stark_vms_frontend/shared/widgets/stale_version_dialog.dart';

import '../helpers/fakes.dart';
import '../helpers/fakes_users.dart';
import '../helpers/fakes_v2.dart';
import '../helpers/pump_app.dart';

/// v2.1 user management screens (contract 7.7, ADR 0024).
void main() {
  late FakeUserRepository users;

  setUp(() {
    users = FakeUserRepository(
      seed: [
        adminAccount(),
        testUserAccount(id: 7),
        testUserAccount(
          id: 8,
          email: 'old@stark.local',
          fullName: 'Old Officer',
          enabled: false,
        ),
      ],
    );
  });

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(1400, 1000),
  }) async {
    await pumpScreen(
      tester,
      screen,
      size: size,
      overrides: [
        userRepositoryProvider.overrideWithValue(users),
        authControllerProvider.overrideWith(
          () => FakeAuthController(AuthState.signedIn(sessionFor(adminUser))),
        ),
      ],
    );
  }

  Finder fieldText(String key, String text) =>
      find.descendant(of: find.byKey(Key(key)), matching: find.text(text));

  group('users list', () {
    testWidgets('full table with text badges; no reset on the own row', (
      tester,
    ) async {
      await pump(tester, const UsersListScreen());

      expect(find.byKey(const Key('users.table')), findsOneWidget);
      expect(find.text('Fleet Admin (you)'), findsOneWidget);
      expect(find.text('Enabled'), findsNWidgets(2));
      expect(find.text('Disabled'), findsOneWidget);
      expect(find.text('Added by'), findsOneWidget);
      expect(find.text('system'), findsOneWidget); // start-up account
      expect(find.byKey(const ValueKey('user.resetPassword.1')), findsNothing);
      expect(find.byKey(const ValueKey('user.resetPassword.7')), findsOne);
      expect(find.byKey(const ValueKey('user.edit.1')), findsOneWidget);
    });

    testWidgets('compact table on tablets, cards on phones', (tester) async {
      await pump(tester, const UsersListScreen(), size: const Size(800, 900));
      expect(find.byKey(const Key('users.table')), findsOneWidget);
      expect(find.text('Added by'), findsNothing);

      await pump(tester, const UsersListScreen(), size: const Size(400, 900));
      expect(find.byKey(const Key('users.table')), findsNothing);
      expect(find.byKey(const ValueKey('user.card.7')), findsOneWidget);
      expect(find.byKey(const Key('users.addFab')), findsOneWidget);
    });

    testWidgets('search is debounced and sent to the server', (tester) async {
      await pump(tester, const UsersListScreen());
      final before = users.listQueries.length;

      await tester.enterText(find.byKey(const Key('users.search')), 'old');
      await tester.pump(const Duration(milliseconds: 50));
      expect(users.listQueries.length, before);

      await tester.pump(AppConfig.searchDebounce);
      await tester.pumpAndSettle();
      expect(users.listQueries.last.search, 'old');
      expect(find.text('Old Officer'), findsOneWidget);
      expect(find.text('Second Officer'), findsNothing);
    });

    testWidgets('role and status filters', (tester) async {
      await pump(tester, const UsersListScreen());

      await tester.tap(find.byKey(const Key('users.enabledFilter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disabled').last);
      await tester.pumpAndSettle();
      expect(users.listQueries.last.enabled, isFalse);
      expect(find.text('Old Officer'), findsOneWidget);
      expect(find.text('Second Officer'), findsNothing);

      await tester.tap(find.byKey(const Key('users.roleFilter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Admin').last);
      await tester.pumpAndSettle();
      expect(users.listQueries.last.role, UserRole.admin);
      expect(find.text('No users match the search or filters'), findsOne);

      await tester.tap(find.byKey(const Key('users.clearFilters')));
      await tester.pumpAndSettle();
      expect(users.listQueries.last.hasFilters, isFalse);
    });

    testWidgets('error state with retry', (tester) async {
      users.listError = problem(500, type: 'internal', detail: 'Boom.');
      await pump(tester, const UsersListScreen());
      expect(find.text('Boom.'), findsOneWidget);

      users.listError = null;
      await tester.tap(find.byKey(const Key('error.retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('users.table')), findsOneWidget);
    });

    testWidgets('reset password dialog validates and resets', (tester) async {
      await pump(tester, const UsersListScreen());

      await tester.tap(find.byKey(const ValueKey('user.resetPassword.7')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('resetPassword.new')),
        'short',
      );
      await tester.tap(find.byKey(const Key('resetPassword.save')));
      await tester.pump();
      expect(find.text('Password must be at least 8 characters.'), findsOne);
      expect(users.passwordResets, isEmpty);

      await tester.enterText(
        find.byKey(const Key('resetPassword.new')),
        'Temp@2026x',
      );
      await tester.enterText(
        find.byKey(const Key('resetPassword.confirm')),
        'Temp@2026x',
      );
      await tester.tap(find.byKey(const Key('resetPassword.save')));
      await tester.pumpAndSettle();
      expect(users.passwordResets.single, (7, 'Temp@2026x'));
      expect(find.byKey(const Key('resetPassword.dialog')), findsNothing);
      expect(
        find.textContaining('Password of officer2@stark.local reset'),
        findsOne,
      );
    });

    testWidgets('a server password-policy error shows under the field', (
      tester,
    ) async {
      users.resetError = problem(
        400,
        type: 'validation',
        detail: 'Validation failed.',
        errors: [
          {'field': 'newPassword', 'message': 'Password is too long.'},
        ],
      );
      await pump(tester, const UsersListScreen());
      await tester.tap(find.byKey(const ValueKey('user.resetPassword.7')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('resetPassword.new')),
        'Temp@2026x',
      );
      await tester.enterText(
        find.byKey(const Key('resetPassword.confirm')),
        'Temp@2026x',
      );
      await tester.tap(find.byKey(const Key('resetPassword.save')));
      await tester.pumpAndSettle();

      expect(fieldText('resetPassword.new', 'Password is too long.'), findsOne);
      expect(find.byKey(const Key('resetPassword.dialog')), findsOneWidget);
    });
  });

  group('user form', () {
    testWidgets('create asks for a password and lower-cases the e-mail', (
      tester,
    ) async {
      await pump(tester, const UserFormScreen());

      expect(find.byKey(const Key('userForm.password')), findsOneWidget);
      expect(find.byKey(const Key('userForm.enabled')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('userForm.email')),
        ' New.Officer@Stark.local ',
      );
      await tester.enterText(
        find.byKey(const Key('userForm.fullName')),
        'New Officer',
      );
      await tester.enterText(find.byKey(const Key('userForm.password')), 'abc');
      await tester.tap(find.byKey(const Key('userForm.save')));
      await tester.pump();
      expect(find.text('Password must be at least 8 characters.'), findsOne);
      expect(users.created, isEmpty);

      await tester.enterText(
        find.byKey(const Key('userForm.password')),
        'Welcome@2026',
      );
      await tester.enterText(
        find.byKey(const Key('userForm.confirmPassword')),
        'Welcome@2026',
      );
      await tester.tap(find.byKey(const Key('userForm.save')));
      await tester.pumpAndSettle();

      expect(users.created.single.toJson()['email'], 'new.officer@stark.local');
      expect(users.created.single.role, UserRole.staff);
      expect(find.text('Navigated to /users'), findsOneWidget);
    });

    testWidgets('409 duplicate-email shows under the e-mail field', (
      tester,
    ) async {
      const message = 'E-mail officer2@stark.local is already registered.';
      users.saveError = problem(
        409,
        type: 'duplicate-email',
        detail: message,
        errors: [
          {'field': 'email', 'message': message},
        ],
      );
      await pump(tester, const UserFormScreen());
      await tester.enterText(
        find.byKey(const Key('userForm.email')),
        'officer2@stark.local',
      );
      await tester.enterText(
        find.byKey(const Key('userForm.fullName')),
        'Second Officer',
      );
      await tester.enterText(
        find.byKey(const Key('userForm.password')),
        'Welcome@2026',
      );
      await tester.enterText(
        find.byKey(const Key('userForm.confirmPassword')),
        'Welcome@2026',
      );
      await tester.tap(find.byKey(const Key('userForm.save')));
      await tester.pumpAndSettle();

      expect(fieldText('userForm.email', message), findsOneWidget);
    });

    testWidgets('edit: e-mail read-only, no password field', (tester) async {
      await pump(tester, const UserFormScreen(userId: 7));

      final email = tester.widget<TextFormField>(
        find.byKey(const Key('userForm.email')),
      );
      expect(email.enabled, isFalse);
      expect(fieldText('userForm.email', 'officer2@stark.local'), findsOne);
      expect(find.byKey(const Key('userForm.password')), findsNothing);
      expect(find.byKey(const Key('userForm.enabled')), findsOneWidget);
    });

    testWidgets('disabling needs confirmation; the save sends the version', (
      tester,
    ) async {
      users.users[1] = testUserAccount(id: 7, version: 3);
      await pump(tester, const UserFormScreen(userId: 7));

      await tester.tap(find.byKey(const Key('userForm.enabled')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('userForm.save')));
      await tester.pumpAndSettle();
      expect(find.text('Disable officer2@stark.local?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirm.cancel')));
      await tester.pumpAndSettle();
      expect(users.updates, isEmpty);

      await tester.tap(find.byKey(const Key('userForm.save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm.ok')));
      await tester.pumpAndSettle();

      final (id, input, version) = users.updates.single;
      expect(id, 7);
      expect(input.enabled, isFalse);
      expect(version, 3);
      expect(find.text('Navigated to /users'), findsOneWidget);
    });

    testWidgets('a name-only change needs no confirmation', (tester) async {
      await pump(tester, const UserFormScreen(userId: 7));

      await tester.enterText(
        find.byKey(const Key('userForm.fullName')),
        'Renamed Officer',
      );
      await tester.tap(find.byKey(const Key('userForm.save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('confirm.ok')), findsNothing);
      expect(users.updates.single.$2.fullName, 'Renamed Officer');
    });

    testWidgets('own account: role and enabled are locked', (tester) async {
      await pump(tester, const UserFormScreen(userId: 1));

      final role = tester.widget<DropdownButton<UserRole>>(
        find.descendant(
          of: find.byKey(const Key('userForm.role')),
          matching: find.byType(DropdownButton<UserRole>),
        ),
      );
      expect(role.onChanged, isNull);
      final enabled = tester.widget<SwitchListTile>(
        find.byKey(const Key('userForm.enabled')),
      );
      expect(enabled.onChanged, isNull);
      expect(
        find.textContaining('cannot disable your own account'),
        findsWidgets,
      );
    });

    testWidgets('409 last-admin is shown as a message', (tester) async {
      users.saveError = problem(
        409,
        type: 'last-admin',
        detail: 'At least one enabled ADMIN must remain.',
      );
      await pump(tester, const UserFormScreen(userId: 7));
      await tester.tap(find.byKey(const Key('userForm.save')));
      await tester.pumpAndSettle();

      expect(find.text('At least one enabled ADMIN must remain.'), findsOne);
    });

    testWidgets('409 stale-version: Reload refills from the server', (
      tester,
    ) async {
      await pump(tester, const UserFormScreen(userId: 7));
      users.saveError = problem(
        409,
        type: 'stale-version',
        detail:
            'This user was changed by someone else since you opened it. '
            'Reload and try again.',
      );
      await tester.enterText(
        find.byKey(const Key('userForm.fullName')),
        'My edit',
      );
      await tester.tap(find.byKey(const Key('userForm.save')));
      await tester.pumpAndSettle();
      expect(find.text(StaleVersionDialog.title), findsOneWidget);

      users.users[1] = testUserAccount(
        id: 7,
        fullName: 'Changed Elsewhere',
        version: 1,
      );
      await tester.tap(find.byKey(const Key('staleVersion.reload')));
      await tester.pumpAndSettle();
      expect(fieldText('userForm.fullName', 'Changed Elsewhere'), findsOne);

      users.saveError = null;
      await tester.tap(find.byKey(const Key('userForm.save')));
      await tester.pumpAndSettle();
      expect(users.updates.map((u) => u.$3), [0, 1]);
    });
  });
}
