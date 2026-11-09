import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stark_vms_frontend/core/network/network_providers.dart';
import 'package:stark_vms_frontend/core/storage/preferences_provider.dart';
import 'package:stark_vms_frontend/core/utils/clock.dart';
import 'package:stark_vms_frontend/features/auth/data/auth_models.dart';
import 'package:stark_vms_frontend/features/auth/data/auth_repository.dart';
import 'package:stark_vms_frontend/features/auth/presentation/auth_controller.dart';

import '../helpers/fakes.dart';

void main() {
  final now = DateTime.utc(2026, 11, 10, 8);
  const storageKey = 'stark_vms.session';

  Future<ProviderContainer> containerWith(Map<String, Object> stored) async {
    SharedPreferences.setMockInitialValues(stored);
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        clockProvider.overrideWithValue(FixedClock(now)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  String storedSession({required DateTime expiresAt}) {
    return jsonEncode(
      AuthSession(
        accessToken: 'stored-token',
        expiresAt: expiresAt,
        user: staffUser,
      ).toJson(),
    );
  }

  group('AuthController (FR-AUTH-01, FR-AUTH-02)', () {
    test('starts signed out without a stored session', () async {
      final container = await containerWith({});

      final state = await container.read(authControllerProvider.future);

      expect(state.isAuthenticated, isFalse);
      expect(state.notice, isNull);
    });

    test('login stores the session and the token', () async {
      final container = await containerWith({});
      await container.read(authControllerProvider.future);

      await container
          .read(authControllerProvider.notifier)
          .login(email: 'admin@stark.local', password: 'Admin@12345');

      final state = container.read(authControllerProvider).requireValue;
      expect(state.user?.email, 'admin@stark.local');
      expect(state.session?.expiresAt, now.add(const Duration(hours: 1)));
      expect(container.read(accessTokenHolderProvider).token, 'test-token');
      expect(
        container.read(sharedPreferencesProvider).getString(storageKey),
        isNotNull,
      );
    });

    test('restores an unexpired session after a reload', () async {
      final container = await containerWith({
        storageKey: storedSession(
          expiresAt: now.add(const Duration(minutes: 30)),
        ),
      });

      final state = await container.read(authControllerProvider.future);

      expect(state.isAuthenticated, isTrue);
      expect(container.read(accessTokenHolderProvider).token, 'stored-token');
    });

    test('an expired stored session signs out with a notice', () async {
      final container = await containerWith({
        storageKey: storedSession(
          expiresAt: now.subtract(const Duration(minutes: 1)),
        ),
      });

      final state = await container.read(authControllerProvider.future);

      expect(state.isAuthenticated, isFalse);
      expect(state.notice, AuthState.sessionExpiredNotice);
      expect(
        container.read(sharedPreferencesProvider).getString(storageKey),
        isNull,
      );
    });

    test('a 401 from any request signs out with "session expired"', () async {
      final container = await containerWith({
        storageKey: storedSession(
          expiresAt: now.add(const Duration(minutes: 30)),
        ),
      });
      await container.read(authControllerProvider.future);

      container.read(unauthorizedEventsProvider).notify();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(authControllerProvider).requireValue;
      expect(state.isAuthenticated, isFalse);
      expect(state.notice, AuthState.sessionExpiredNotice);
      expect(container.read(accessTokenHolderProvider).token, isNull);
    });

    test('logout clears the token', () async {
      final container = await containerWith({
        storageKey: storedSession(
          expiresAt: now.add(const Duration(minutes: 30)),
        ),
      });
      await container.read(authControllerProvider.future);

      await container.read(authControllerProvider.notifier).logout();

      expect(
        container.read(authControllerProvider).requireValue.isAuthenticated,
        isFalse,
      );
      expect(container.read(accessTokenHolderProvider).token, isNull);
      expect(
        container.read(sharedPreferencesProvider).getString(storageKey),
        isNull,
      );
    });
  });
}
