import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stark_vms_frontend/core/network/api_exception.dart';
import 'package:stark_vms_frontend/core/storage/preferences_provider.dart';
import 'package:stark_vms_frontend/features/auth/data/auth_repository.dart';
import 'package:stark_vms_frontend/features/auth/presentation/login_controller.dart';

import '../helpers/fakes.dart';
import '../helpers/recording_adapter.dart';

/// v1.1 login throttling on the client (ADR 0022, contract 6.1): a 429 is
/// shown with the server detail and never ends a session.
void main() {
  const detail = 'Too many failed login attempts. Try again in 14 minutes.';
  const throttledBody = {
    'type': 'https://stark-vms/errors/too-many-login-attempts',
    'title': 'Too many login attempts',
    'status': 429,
    'detail': detail,
    'instance': '/api/v1/auth/login',
  };

  test('a 429 Problem Details keeps the detail and is not a 401', () {
    final error = ApiException.fromProblemDetails(throttledBody);

    expect(error.isTooManyRequests, isTrue);
    expect(error.isUnauthorized, isFalse);
    expect(error.message, detail);
    expect(error.hasType('too-many-login-attempts'), isTrue);
  });

  test('a 429 without a body still gets a helpful message', () {
    final error = ApiException.fromProblemDetails(null, statusCode: 429);

    expect(error.message, contains('Too many failed login attempts'));
  });

  test(
    'a 429 from login (or anywhere) never triggers the 401 sign-out',
    () async {
      var unauthorized = 0;
      final adapter = RecordingAdapter(
        (_) => const CannedResponse(
          429,
          body: throttledBody,
          headers: {
            'retry-after': ['840'],
          },
        ),
      );
      final client = apiClientFor(
        adapter,
        onUnauthorized: () => unauthorized++,
      );

      await expectLater(
        client.post('/auth/login', body: {'email': 'a@b.c', 'password': 'x'}),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 429)),
      );
      await expectLater(client.get('/vehicles'), throwsA(isA<ApiException>()));
      expect(unauthorized, 0);
    },
  );

  test(
    'LoginController shows the 429 detail, not "invalid credentials"',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(
              loginError: ApiException.fromProblemDetails(throttledBody),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(loginControllerProvider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(loginControllerProvider.future);

      await container
          .read(loginControllerProvider.notifier)
          .submit(email: 'admin@stark.local', password: 'Admin@12345');

      final state = container.read(loginControllerProvider);
      expect(state.error, detail);
      expect(state.error, isNot(LoginController.invalidCredentialsMessage));
    },
  );
}
