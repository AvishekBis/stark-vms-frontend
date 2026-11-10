import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/config/app_config.dart';

void main() {
  test('the demo credentials hint is off by default in release builds', () {
    // Without --dart-define=SHOW_DEMO_CREDENTIALS the build mode decides:
    // shown in debug / profile (and tests), hidden in release.
    if (!const bool.hasEnvironment('SHOW_DEMO_CREDENTIALS')) {
      expect(AppConfig.showDemoCredentials, !kReleaseMode);
    }
  });

  test('the demo credential lines fall back to the local seed accounts', () {
    // The deployed backend has its own demo passwords, so the two lines of the
    // login hint come from --dart-define. A build that passes neither (this
    // test run, and every local `flutter run`) gets the local seed values.
    if (!const bool.hasEnvironment('DEMO_ADMIN')) {
      expect(AppConfig.demoAdmin, 'admin@stark.local / Admin@12345');
    }
    if (!const bool.hasEnvironment('DEMO_STAFF')) {
      expect(AppConfig.demoStaff, 'staff@stark.local / Staff@12345');
    }
  });

  test('a dart-define overrides the demo credential line it names', () {
    // `String.fromEnvironment` is folded at compile time, so a test cannot set
    // the define itself; what it can check is that each line reads its OWN
    // define and nothing else. Run with
    //   flutter test --dart-define=DEMO_ADMIN='a@b / x'
    // and this asserts the override reached the hint.
    if (const bool.hasEnvironment('DEMO_ADMIN')) {
      expect(AppConfig.demoAdmin, const String.fromEnvironment('DEMO_ADMIN'));
      expect(AppConfig.demoAdmin, isNot('admin@stark.local / Admin@12345'));
    }
    if (const bool.hasEnvironment('DEMO_STAFF')) {
      expect(AppConfig.demoStaff, const String.fromEnvironment('DEMO_STAFF'));
    }
  });
}
