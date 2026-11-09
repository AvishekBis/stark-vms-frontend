import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stark_vms_frontend/core/network/api_exception.dart';
import 'package:stark_vms_frontend/core/network/network_providers.dart';
import 'package:stark_vms_frontend/core/router/app_router.dart';
import 'package:stark_vms_frontend/core/storage/preferences_provider.dart';
import 'package:stark_vms_frontend/core/utils/clock.dart';
import 'package:stark_vms_frontend/core/utils/validators.dart';
import 'package:stark_vms_frontend/features/auth/data/auth_models.dart';
import 'package:stark_vms_frontend/features/auth/data/auth_repository.dart';
import 'package:stark_vms_frontend/features/auth/presentation/auth_controller.dart';
import 'package:stark_vms_frontend/features/users/data/user_account.dart';
import 'package:stark_vms_frontend/features/users/data/user_query.dart';
import 'package:stark_vms_frontend/features/users/data/user_repository.dart';
import 'package:stark_vms_frontend/features/users/presentation/user_providers.dart';

import '../helpers/fakes.dart';
import '../helpers/fakes_users.dart';
import '../helpers/fakes_v2.dart';
import '../helpers/recording_adapter.dart';

/// v2.1 ADMIN user management on the client (ADR 0024, contract 7.3).
void main() {
  group('UserAccount (7.3.1)', () {
    test('parses the contract example', () {
      final user = UserAccount.fromJson({
        'id': 7,
        'email': 'officer2@stark.local',
        'fullName': 'Second Officer',
        'role': 'STAFF',
        'enabled': false,
        'createdAt': '2026-11-07T08:00:00Z',
        'updatedAt': '2026-11-07T08:00:00Z',
        'createdBy': 'admin@stark.local',
        'version': 2,
      });

      expect(user.id, 7);
      expect(user.role, UserRole.staff);
      expect(user.enabled, isFalse);
      expect(user.createdBy, 'admin@stark.local');
      expect(user.version, 2);
      expect(user.createdAt, DateTime.utc(2026, 11, 7, 8));
    });

    test(
      'start-up accounts have createdBy "system"; a missing one is null',
      () {
        final user = UserAccount.fromJson({
          'id': 1,
          'email': 'admin@stark.local',
          'fullName': 'Fleet Admin',
          'role': 'ADMIN',
          'enabled': true,
          'createdBy': 'system',
          'version': 0,
        });
        expect(user.createdBy, 'system');
        final legacy = UserAccount.fromJson({
          'id': 2,
          'email': 'old@stark.local',
          'role': 'STAFF',
          'enabled': true,
        });
        expect(legacy.createdBy, isNull);
        expect(user.isAdmin, isTrue);
      },
    );
  });

  group('request bodies (7.3.3)', () {
    test('create: e-mail trimmed and lower-cased, password as typed, no '
        'version', () {
      const input = CreateUserInput(
        email: ' Officer2@Stark.local ',
        fullName: ' Second Officer ',
        role: UserRole.staff,
        password: ' Welcome@2026 ',
      );
      expect(input.toJson(), {
        'email': 'officer2@stark.local',
        'fullName': 'Second Officer',
        'role': 'STAFF',
        'password': ' Welcome@2026 ',
      });
    });

    test('update: every field plus version, never the e-mail', () {
      const input = UpdateUserInput(
        fullName: 'Second Officer',
        role: UserRole.admin,
        enabled: false,
      );
      expect(input.toUpdateJson(3), {
        'fullName': 'Second Officer',
        'role': 'ADMIN',
        'enabled': false,
        'version': 3,
      });
    });
  });

  group('UserQuery (7.3.2)', () {
    test('defaults to email,asc and sends only set filters', () {
      expect(const UserQuery().toQueryParameters(), {
        'page': 0,
        'size': 20,
        'sort': 'email,asc',
      });
      expect(
        const UserQuery(
          search: ' officer ',
          role: UserRole.staff,
          enabled: false,
          size: 500,
          sortField: UserSortField.createdAt,
          sortDirection: SortDirection.descending,
        ).toQueryParameters(),
        {
          'page': 0,
          'size': 100,
          'sort': 'createdAt,desc',
          'search': 'officer',
          'role': 'STAFF',
          'enabled': false,
        },
      );
    });

    test('a filter change goes back to the first page', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(userQueryProvider.notifier);

      controller.goToPage(3);
      controller.setRole(UserRole.admin);
      expect(container.read(userQueryProvider).page, 0);

      controller.goToPage(2);
      controller.setEnabled(true);
      expect(container.read(userQueryProvider).page, 0);
      expect(container.read(userQueryProvider).hasFilters, isTrue);

      controller.clearFilters();
      expect(container.read(userQueryProvider).hasFilters, isFalse);
    });
  });

  group('UserValidators (password policy 8 chars … 72 bytes)', () {
    test('minimum length 8', () {
      expect(UserValidators.newPassword(''), 'Password is required.');
      expect(UserValidators.newPassword('1234567'), contains('at least 8'));
      expect(UserValidators.newPassword('12345678'), isNull);
      // Code points, as on the server: 4 emoji are 8 UTF-16 units but only
      // 4 characters.
      const emoji = '\u{1F600}';
      expect(UserValidators.newPassword(emoji * 4), contains('at least 8'));
      expect(UserValidators.newPassword(emoji * 8), isNull);
    });

    test('maximum 72 bytes in UTF-8, not 72 characters', () {
      expect(UserValidators.newPassword('a' * 72), isNull);
      expect(UserValidators.newPassword('a' * 73), contains('too long'));
      // 25 characters but 75 bytes ('€' is 3 bytes in UTF-8).
      final euros = '€' * 25;
      expect(utf8.encode(euros).length, 75);
      expect(UserValidators.newPassword(euros), contains('too long'));
    });

    test('confirmation must match', () {
      expect(UserValidators.confirmPassword('abc', 'abd'), isNotNull);
      expect(UserValidators.confirmPassword('abc', 'abc'), isNull);
    });

    test('e-mail and full name', () {
      expect(UserValidators.email('not-an-email'), isNotNull);
      expect(
        UserValidators.email('${'a' * 250}@stark.local'),
        contains('at most 255'),
      );
      expect(UserValidators.email('officer@stark.local'), isNull);
      expect(UserValidators.fullName(' '), 'Full name is required.');
      expect(UserValidators.fullName('a' * 101), contains('at most 100'));
    });
  });

  group('ApiUserRepository and own password change (endpoints of 7.4)', () {
    const userJson = {
      'id': 7,
      'email': 'officer2@stark.local',
      'fullName': 'Second Officer',
      'role': 'STAFF',
      'enabled': true,
      'version': 1,
    };

    test('paths, methods and bodies', () async {
      final adapter = RecordingAdapter((request) {
        if (request.path.endsWith('/password')) {
          return const CannedResponse(204);
        }
        if (request.method == 'GET' && request.path == '/users') {
          return const CannedResponse(
            200,
            body: {
              'content': [userJson],
              'page': 0,
              'size': 20,
              'totalElements': 1,
              'totalPages': 1,
            },
          );
        }
        return CannedResponse(
          request.method == 'POST' ? 201 : 200,
          body: userJson,
        );
      });
      final client = apiClientFor(adapter);
      final repository = ApiUserRepository(client);

      final page = await repository.list(
        const UserQuery(search: 'officer', role: UserRole.staff),
      );
      expect(page.content.single.email, 'officer2@stark.local');
      expect(adapter.last.uri.queryParameters, {
        'page': '0',
        'size': '20',
        'sort': 'email,asc',
        'search': 'officer',
        'role': 'STAFF',
      });

      await repository.get(7);
      expect((adapter.last.method, adapter.last.path), ('GET', '/users/7'));

      await repository.create(
        const CreateUserInput(
          email: 'Officer2@Stark.local',
          fullName: 'Second Officer',
          role: UserRole.staff,
          password: 'Welcome@2026',
        ),
      );
      expect((adapter.last.method, adapter.last.path), ('POST', '/users'));
      expect((adapter.last.data as Map)['email'], 'officer2@stark.local');

      await repository.update(
        7,
        const UpdateUserInput(
          fullName: 'Second Officer',
          role: UserRole.staff,
          enabled: false,
        ),
        version: 1,
      );
      expect((adapter.last.method, adapter.last.path), ('PUT', '/users/7'));
      expect((adapter.last.data as Map)['version'], 1);
      expect((adapter.last.data as Map).containsKey('email'), isFalse);

      await repository.resetPassword(7, newPassword: 'Temp@2026x');
      expect(
        (adapter.last.method, adapter.last.path),
        ('POST', '/users/7/password'),
      );
      expect(adapter.last.data, {'newPassword': 'Temp@2026x'});

      await ApiAuthRepository(client).changeOwnPassword(
        currentPassword: 'Staff@12345',
        newPassword: 'N3w-Staff-Pass',
      );
      expect(
        (adapter.last.method, adapter.last.path),
        ('PUT', '/auth/me/password'),
      );
      expect(adapter.last.data, {
        'currentPassword': 'Staff@12345',
        'newPassword': 'N3w-Staff-Pass',
      });
    });

    test('a wrong current password (400) does not sign the user out', () async {
      var unauthorized = 0;
      final adapter = RecordingAdapter.always(
        400,
        body: {
          'type': 'https://stark-vms/errors/validation',
          'status': 400,
          'detail': 'Current password is incorrect.',
          'errors': [
            {
              'field': 'currentPassword',
              'message': 'Current password is incorrect.',
            },
          ],
        },
      );
      final client = apiClientFor(
        adapter,
        onUnauthorized: () => unauthorized++,
      );

      await expectLater(
        ApiAuthRepository(client).changeOwnPassword(
          currentPassword: 'wrong',
          newPassword: 'N3w-Staff-Pass',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.fieldErrors['currentPassword'],
            'currentPassword',
            'Current password is incorrect.',
          ),
        ),
      );
      expect(unauthorized, 0);
    });
  });

  group('UserFormController', () {
    late FakeUserRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakeUserRepository(
        seed: [adminAccount(), testUserAccount(version: 4)],
      );
      container = ProviderContainer(
        overrides: [userRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        userFormControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
    });

    UserFormController controller() =>
        container.read(userFormControllerProvider.notifier);
    const update = UpdateUserInput(
      fullName: 'Second Officer',
      role: UserRole.staff,
      enabled: false,
    );

    test('update sends the loaded version and refreshes the list', () async {
      final saved = await controller().update(repository.users[1], update);

      expect(repository.updates.single.$3, 4);
      expect(saved?.version, 5);
      expect(container.read(userChangesProvider), 1);
    });

    test('409 duplicate-email lands under the e-mail field', () async {
      const message = 'E-mail officer2@stark.local is already registered.';
      repository.saveError = problem(
        409,
        type: 'duplicate-email',
        detail: message,
        errors: [
          {'field': 'email', 'message': message},
        ],
      );

      await controller().create(
        const CreateUserInput(
          email: 'officer2@stark.local',
          fullName: 'Second Officer',
          role: UserRole.staff,
          password: 'Welcome@2026',
        ),
      );

      final state = container.read(userFormControllerProvider);
      expect(state.errorFor('email'), message);
      expect(state.errorMessage, isNull);
    });

    test('409 last-admin and self-modification are general messages', () async {
      for (final (type, detail) in [
        ('last-admin', 'At least one enabled ADMIN must remain.'),
        (
          'self-modification',
          'You cannot disable your own account or remove your own ADMIN role.',
        ),
      ]) {
        repository.saveError = problem(409, type: type, detail: detail);
        await controller().update(repository.users[0], update);
        final state = container.read(userFormControllerProvider);
        expect(state.errorMessage, detail);
        expect(state.isStale, isFalse);
      }
    });

    test('409 stale-version sets isStale', () async {
      repository.saveError = problem(
        409,
        type: 'stale-version',
        detail:
            'This user was changed by someone else since you opened it. '
            'Reload and try again.',
      );

      await controller().update(repository.users[1], update);

      final state = container.read(userFormControllerProvider);
      expect(state.isStale, isTrue);
      expect(state.staleVersionMessage, startsWith('This user was changed'));
    });

    test(
      'a password reset refreshes the list (it bumps the version)',
      () async {
        final subscription = container.listen(
          resetPasswordControllerProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);

        final ok = await container
            .read(resetPasswordControllerProvider.notifier)
            .submit(repository.users[1], 'Temp@2026x');

        expect(ok, isTrue);
        expect(repository.passwordResets.single, (7, 'Temp@2026x'));
        expect(container.read(userChangesProvider), 1);
      },
    );
  });

  group('authRedirect: /users is ADMIN only (7.7)', () {
    final admin = AsyncValue.data(AuthState.signedIn(sessionFor(adminUser)));
    final staff = AsyncValue.data(AuthState.signedIn(sessionFor(staffUser)));

    test('STAFF is sent to the dashboard', () {
      expect(authRedirect(staff, Uri.parse('/users')), '/dashboard');
      expect(authRedirect(staff, Uri.parse('/users/new')), '/dashboard');
      expect(authRedirect(staff, Uri.parse('/users/7/edit')), '/dashboard');
      expect(
        authRedirect(staff, Uri.parse('/login?from=%2Fusers')),
        '/dashboard',
      );
    });

    test('ADMIN may open the user pages', () {
      expect(authRedirect(admin, Uri.parse('/users')), isNull);
      expect(authRedirect(admin, Uri.parse('/users/7/edit')), isNull);
      expect(authRedirect(admin, Uri.parse('/login?from=%2Fusers')), '/users');
    });

    test('a similar path is not mistaken for /users', () {
      expect(authRedirect(staff, Uri.parse('/usersettings')), isNull);
    });
  });

  group('AuthController.changePassword (7.3.4)', () {
    final now = DateTime.utc(2026, 11, 10, 8);
    const storageKey = 'stark_vms.session';
    late FakeAuthRepository repository;

    Future<ProviderContainer> signedInContainer() async {
      SharedPreferences.setMockInitialValues({
        storageKey: jsonEncode(
          AuthSession(
            accessToken: 'old-token',
            expiresAt: now.add(const Duration(minutes: 30)),
            user: staffUser,
          ).toJson(),
        ),
      });
      final preferences = await SharedPreferences.getInstance();
      repository = FakeAuthRepository(
        loginResponse: const LoginResponse(
          accessToken: 'test-token',
          tokenType: 'Bearer',
          expiresIn: Duration(hours: 1),
          user: staffUser,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          authRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(FixedClock(now)),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      return container;
    }

    test(
      'logs in again with the new password and keeps the user signed in',
      () async {
        final container = await signedInContainer();

        final outcome = await container
            .read(authControllerProvider.notifier)
            .changePassword(
              currentPassword: 'Staff@12345',
              newPassword: 'N3w-Staff-Pass',
            );

        expect(outcome, PasswordChangeOutcome.reauthenticated);
        expect(repository.passwordChanges.single, (
          'Staff@12345',
          'N3w-Staff-Pass',
        ));
        expect(repository.logins.single, (
          'staff@stark.local',
          'N3w-Staff-Pass',
        ));
        expect(
          container.read(accessTokenHolderProvider).token,
          FakeAuthRepository.tokenAfterPasswordChange,
        );
        expect(
          container.read(sharedPreferencesProvider).getString(storageKey),
          contains(FakeAuthRepository.tokenAfterPasswordChange),
        );
        expect(
          container.read(authControllerProvider).requireValue.isAuthenticated,
          isTrue,
        );
      },
    );

    test('a failed re-login signs out with an explanation', () async {
      final container = await signedInContainer();
      repository.loginErrorAfterPasswordChange = problem(
        401,
        type: 'unauthorized',
        detail: 'Invalid email or password.',
      );

      final outcome = await container
          .read(authControllerProvider.notifier)
          .changePassword(
            currentPassword: 'Staff@12345',
            newPassword: 'N3w-Staff-Pass',
          );

      final state = container.read(authControllerProvider).requireValue;
      expect(outcome, PasswordChangeOutcome.signedOut);
      expect(state.isAuthenticated, isFalse);
      expect(state.notice, AuthState.passwordChangedNotice);
      expect(container.read(accessTokenHolderProvider).token, isNull);
    });

    test('a 401 from another request during the re-login is ignored', () async {
      final container = await signedInContainer();
      // An old-token request is answered 401 while the re-login runs.
      repository.onLogin = container.read(unauthorizedEventsProvider).notify;
      final states = <AuthState>[];
      final subscription = container.listen(
        authControllerProvider,
        (_, next) => states.addAll([?next.valueOrNull]),
      );
      addTearDown(subscription.close);

      final outcome = await container
          .read(authControllerProvider.notifier)
          .changePassword(
            currentPassword: 'Staff@12345',
            newPassword: 'N3w-Staff-Pass',
          );
      await pumpEventQueue();

      expect(outcome, PasswordChangeOutcome.reauthenticated);
      // Never signed out on the way ("session expired" would flash).
      expect(states.where((state) => !state.isAuthenticated), isEmpty);
      expect(
        container.read(authControllerProvider).requireValue.isAuthenticated,
        isTrue,
      );
    });

    test('a rejected change keeps the session and logs in nobody', () async {
      final container = await signedInContainer();
      repository.changePasswordError = problem(
        400,
        type: 'validation',
        detail: 'Current password is incorrect.',
        errors: [
          {
            'field': 'currentPassword',
            'message': 'Current password is incorrect.',
          },
        ],
      );

      await expectLater(
        container
            .read(authControllerProvider.notifier)
            .changePassword(currentPassword: 'wrong', newPassword: 'N3w-Pass!'),
        throwsA(isA<ApiException>()),
      );

      expect(repository.logins, isEmpty);
      expect(container.read(accessTokenHolderProvider).token, 'old-token');
      expect(
        container.read(authControllerProvider).requireValue.isAuthenticated,
        isTrue,
      );
    });
  });
}
