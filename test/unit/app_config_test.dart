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
}
