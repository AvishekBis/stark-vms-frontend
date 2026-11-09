import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/config/app_config.dart';
import 'package:stark_vms_frontend/shared/widgets/missing_configuration_app.dart';

void main() {
  test('API_BASE_URL has no hard-coded default', () {
    expect(
      AppConfig.isApiConfigured,
      const bool.hasEnvironment('API_BASE_URL'),
    );
  });

  testWidgets('a build without API_BASE_URL explains how to fix it', (
    tester,
  ) async {
    await tester.pumpWidget(const MissingConfigurationApp());

    expect(find.byKey(const Key('config.missingApiBaseUrl')), findsOneWidget);
    expect(find.text(MissingConfigurationApp.title), findsOneWidget);
    expect(find.textContaining('API_BASE_URL'), findsOneWidget);
  });
}
