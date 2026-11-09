import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's [SharedPreferences] instance.
///
/// It is loaded once in `bootstrap()` and injected with
/// `sharedPreferencesProvider.overrideWithValue(...)`.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in bootstrap().',
  ),
);
