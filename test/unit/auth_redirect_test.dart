import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/router/app_router.dart';
import 'package:stark_vms_frontend/features/auth/presentation/auth_controller.dart';

import '../helpers/fakes.dart';

void main() {
  final signedIn = AsyncValue.data(AuthState.signedIn(sessionFor(adminUser)));
  const signedOut = AsyncValue.data(AuthState.signedOut());
  const restoring = AsyncValue<AuthState>.loading();

  group('authRedirect (FR-AUTH-02)', () {
    test('signed-out users are sent to login, keeping the target', () {
      expect(
        authRedirect(signedOut, Uri.parse('/vehicles/12')),
        '/login?from=%2Fvehicles%2F12',
      );
      expect(authRedirect(signedOut, Uri.parse('/dashboard')), '/login');
      expect(authRedirect(signedOut, Uri.parse('/login')), isNull);
    });

    test('signed-in users leave login for the target or the dashboard', () {
      expect(authRedirect(signedIn, Uri.parse('/login')), '/dashboard');
      expect(
        authRedirect(signedIn, Uri.parse('/login?from=%2Fvehicles%2F12')),
        '/vehicles/12',
      );
      expect(authRedirect(signedIn, Uri.parse('/vehicles')), isNull);
    });

    test('external redirect targets are ignored', () {
      expect(
        authRedirect(signedIn, Uri.parse('/login?from=%2F%2Fevil.example')),
        '/dashboard',
      );
    });

    test('while the session is restored the splash screen is shown', () {
      expect(
        authRedirect(restoring, Uri.parse('/vehicles')),
        '/splash?from=%2Fvehicles',
      );
      expect(authRedirect(restoring, Uri.parse('/splash')), isNull);
    });
  });
}
