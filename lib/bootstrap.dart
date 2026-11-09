import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/storage/preferences_provider.dart';
import 'shared/widgets/missing_configuration_app.dart';

/// Loads what the app needs before the first frame, then starts it.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppConfig.isApiConfigured) {
    runApp(const MissingConfigurationApp());
    return;
  }
  _wakeUpBackend();
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const StarkVmsApp(),
    ),
  );
}

/// Fire-and-forget `GET /actuator/health` at start-up (NFR availability):
/// a sleeping Render free instance starts waking while the user types the
/// login details, instead of only when the form is submitted. The answer
/// (or a CORS / network error) is ignored; nothing waits for it.
void _wakeUpBackend() {
  final healthUrl = Uri.parse(AppConfig.apiBaseUrl)
      .resolve('/actuator/health')
      .toString();
  unawaited(Dio().get<void>(healthUrl).then((_) {}, onError: (Object _) {}));
}
