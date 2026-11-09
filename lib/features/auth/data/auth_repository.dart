import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/storage/preferences_provider.dart';
import 'auth_models.dart';

/// Auth endpoints (FR-AUTH-01, FR-AUTH-02).
abstract interface class AuthRepository {
  /// `POST /auth/login`. Throws [ApiException] (401 for bad credentials).
  Future<LoginResponse> login({
    required String email,
    required String password,
  });

  /// `GET /auth/me` with the current token.
  Future<User> currentUser();
}

class ApiAuthRepository implements AuthRepository {
  const ApiAuthRepository(this._client);

  final ApiClient _client;

  @override
  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    final body = await _client.post(
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
    );
    return LoginResponse.fromJson(_asJsonObject(body));
  }

  @override
  Future<User> currentUser() async {
    final body = await _client.get('/auth/me');
    return User.fromJson(_asJsonObject(body));
  }

  static Map<String, dynamic> _asJsonObject(Object? body) {
    if (body is Map<String, dynamic>) {
      return body;
    }
    throw const ApiException(
      kind: ApiErrorKind.unknown,
      message: 'The server sent an unexpected response.',
    );
  }
}

/// Persists the session in browser storage so a reload keeps the user
/// logged in until the token expires (see README for the XSS trade-off).
class SessionStorage {
  const SessionStorage(this._preferences);

  static const String _sessionKey = 'stark_vms.session';

  final SharedPreferences _preferences;

  AuthSession? read() {
    final raw = _preferences.getString(_sessionKey);
    if (raw == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? AuthSession.fromJson(decoded)
          : null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> save(AuthSession session) {
    return _preferences.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  Future<void> clear() => _preferences.remove(_sessionKey);
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiAuthRepository(ref.watch(apiClientProvider)),
);

final sessionStorageProvider = Provider<SessionStorage>(
  (ref) => SessionStorage(ref.watch(sharedPreferencesProvider)),
);
