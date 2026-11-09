import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'state_views.dart';

/// Shown instead of the app when the build has no `API_BASE_URL`
/// (`--dart-define=API_BASE_URL=https://<host>/api/v1`).
class MissingConfigurationApp extends StatelessWidget {
  const MissingConfigurationApp({super.key});

  static const String title = 'API address not configured';
  static const String message =
      'This build was made without an API address. Rebuild it with '
      '--dart-define=API_BASE_URL=https://<server>/api/v1.';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stark Group VMS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const Scaffold(
        body: ErrorView(
          key: Key('config.missingApiBaseUrl'),
          title: title,
          message: message,
        ),
      ),
    );
  }
}
