import 'package:flutter/foundation.dart';

/// Build-time configuration, injected with `--dart-define`.
///
/// Example: `flutter build web --dart-define=API_BASE_URL=https://vms.onrender.com/api/v1`
abstract final class AppConfig {
  /// Base URL of the Stark VMS REST API, including the `/api/v1` prefix.
  ///
  /// It has no default on purpose (guideline 14.2): a build without
  /// `--dart-define=API_BASE_URL=...` shows a configuration error instead of
  /// silently calling a hard-coded server.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static bool get isApiConfigured => apiBaseUrl.trim().isNotEmpty;

  /// Shows the demo credentials hint on the login screen.
  ///
  /// On by default only in debug / profile builds; a release build shows it
  /// only with `--dart-define=SHOW_DEMO_CREDENTIALS=true` (e.g. a course
  /// demo deployment), so production never advertises the demo password.
  static const bool showDemoCredentials = bool.fromEnvironment(
    'SHOW_DEMO_CREDENTIALS',
    defaultValue: !kReleaseMode,
  );

  /// Generous timeout: a sleeping Render free instance can take close to a
  /// minute to answer the first request.
  static const Duration requestTimeout = Duration(seconds: 75);

  /// After this delay a pending request shows "Connecting to server…".
  static const Duration slowRequestThreshold = Duration(seconds: 3);

  /// Debounce for search fields (guideline 14.2: 300–400 ms).
  static const Duration searchDebounce = Duration(milliseconds: 350);
}
