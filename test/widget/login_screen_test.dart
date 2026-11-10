import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stark_vms_frontend/core/config/app_config.dart';
import 'package:stark_vms_frontend/core/network/api_exception.dart';
import 'package:stark_vms_frontend/core/storage/preferences_provider.dart';
import 'package:stark_vms_frontend/features/auth/data/auth_repository.dart';
import 'package:stark_vms_frontend/features/auth/presentation/login_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  Future<FakeAuthRepository> pumpLogin(
    WidgetTester tester, {
    ApiException? loginError,
  }) async {
    final repository = FakeAuthRepository(loginError: loginError);
    await pumpScreen(
      tester,
      const LoginScreen(),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    return repository;
  }

  testWidgets('validates email and password before calling the API', (
    tester,
  ) async {
    final repository = await pumpLogin(tester);

    await tester.tap(find.byKey(const Key('login.submit')));
    await tester.pump();

    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
    expect(repository.loginCalls, 0);

    await tester.enterText(
      find.byKey(const Key('login.email')),
      'not-an-email',
    );
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('shows the generic message on 401 (FR-AUTH-01)', (tester) async {
    final repository = await pumpLogin(
      tester,
      loginError: ApiException.fromProblemDetails({
        'type': 'https://stark-vms/errors/unauthorized',
        'title': 'Unauthorized',
        'status': 401,
        'detail': 'Invalid email or password.',
      }),
    );

    await tester.enterText(
      find.byKey(const Key('login.email')),
      'admin@stark.local',
    );
    await tester.enterText(
      find.byKey(const Key('login.password')),
      'wrong-password',
    );
    await tester.tap(find.byKey(const Key('login.submit')));
    await tester.pumpAndSettle();

    expect(repository.loginCalls, 1);
    expect(find.byKey(const Key('login.error')), findsOneWidget);
    expect(find.text('Invalid email or password.'), findsOneWidget);
  });

  testWidgets('shows the 429 detail, not "invalid credentials" (ADR 0022)', (
    tester,
  ) async {
    const detail = 'Too many failed login attempts. Try again in 14 minutes.';
    await pumpLogin(
      tester,
      loginError: ApiException.fromProblemDetails({
        'type': 'https://stark-vms/errors/too-many-login-attempts',
        'title': 'Too many login attempts',
        'status': 429,
        'detail': detail,
      }),
    );

    await tester.enterText(
      find.byKey(const Key('login.email')),
      'admin@stark.local',
    );
    await tester.enterText(
      find.byKey(const Key('login.password')),
      'Admin@12345',
    );
    await tester.tap(find.byKey(const Key('login.submit')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('login.error')),
        matching: find.text(detail),
      ),
      findsOneWidget,
    );
    expect(find.text('Invalid email or password.'), findsNothing);
  });

  testWidgets('password visibility can be toggled', (tester) async {
    await pumpLogin(tester);

    EditableText passwordField() => tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('login.password')),
        matching: find.byType(EditableText),
      ),
    );

    expect(passwordField().obscureText, isTrue);
    await tester.tap(find.byKey(const Key('login.togglePassword')));
    await tester.pump();
    expect(passwordField().obscureText, isFalse);
  });

  testWidgets('the demo hint names the configured credentials', (tester) async {
    // The deployed backend's demo passwords differ from the local seed, so the
    // hint must read its two lines from the DEMO_ADMIN / DEMO_STAFF
    // dart-defines rather than hard-code them. Asserting against AppConfig
    // (not against literals) is what proves that: the test passes on a plain
    // run, where the fallbacks apply, AND on a build that overrides them.
    await pumpLogin(tester);

    final hint = tester.widget<Text>(find.byKey(const Key('login.demoHint')));
    expect(AppConfig.showDemoCredentials, isTrue, reason: 'debug build');
    expect(
      hint.data,
      'Demo accounts (non-real credentials)\n'
      'Admin: ${AppConfig.demoAdmin}\n'
      'Staff: ${AppConfig.demoStaff}',
    );
    // The wording that keeps the hint honest stays in the text.
    expect(hint.data, contains('non-real credentials'));
  });
}
