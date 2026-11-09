import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/utils/clock.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';

/// Who is logged in. [notice] explains why the user was signed out.
class AuthState {
  const AuthState.signedOut({this.notice}) : session = null;

  const AuthState.signedIn(AuthSession this.session) : notice = null;

  static const String sessionExpiredNotice =
      'Your session has expired. Please log in again.';
  static const String loggedOutNotice = 'You have been logged out.';

  final AuthSession? session;
  final String? notice;

  bool get isAuthenticated => session != null;
  User? get user => session?.user;
}

/// Owns the session lifecycle (FR-AUTH-01, FR-AUTH-02):
/// login, logout, restore on reload, auto-logout at token expiry and
/// sign-out when any request comes back 401.
class AuthController extends AsyncNotifier<AuthState> {
  Timer? _expiryTimer;

  @override
  Future<AuthState> build() async {
    final subscription = ref
        .watch(unauthorizedEventsProvider)
        .stream
        .listen((_) => expireSession());
    ref.onDispose(() {
      subscription.cancel();
      _expiryTimer?.cancel();
    });
    return _restoreSession();
  }

  Future<void> login({required String email, required String password}) async {
    final response = await ref
        .read(authRepositoryProvider)
        .login(email: email, password: password);
    final session = AuthSession.fromLogin(response, now: _now());
    await ref.read(sessionStorageProvider).save(session);
    _activate(session);
    state = AsyncData(AuthState.signedIn(session));
  }

  Future<void> logout() => _signOut(AuthState.loggedOutNotice);

  /// Called when the token expires or the server answers 401.
  Future<void> expireSession() async {
    if (state.valueOrNull?.isAuthenticated ?? false) {
      await _signOut(AuthState.sessionExpiredNotice);
    }
  }

  Future<AuthState> _restoreSession() async {
    final stored = ref.read(sessionStorageProvider).read();
    if (stored == null) {
      return const AuthState.signedOut();
    }
    if (stored.isExpiredAt(_now())) {
      await _clearSession();
      return const AuthState.signedOut(notice: AuthState.sessionExpiredNotice);
    }
    _activate(stored);
    try {
      final user = await ref.read(authRepositoryProvider).currentUser();
      final refreshed = stored.copyWith(user: user);
      await ref.read(sessionStorageProvider).save(refreshed);
      return AuthState.signedIn(refreshed);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _clearSession();
        return const AuthState.signedOut(
          notice: AuthState.sessionExpiredNotice,
        );
      }
      return AuthState.signedIn(stored);
    }
  }

  void _activate(AuthSession session) {
    ref.read(accessTokenHolderProvider).token = session.accessToken;
    _expiryTimer?.cancel();
    final remaining = session.expiresAt.difference(_now().toUtc());
    _expiryTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      expireSession,
    );
  }

  Future<void> _signOut(String notice) async {
    await _clearSession();
    state = AsyncData(AuthState.signedOut(notice: notice));
  }

  Future<void> _clearSession() async {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    ref.read(accessTokenHolderProvider).token = null;
    await ref.read(sessionStorageProvider).clear();
  }

  DateTime _now() => ref.read(clockProvider).now();
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Convenience: the logged-in user, or `null`.
final currentUserProvider = Provider<User?>(
  (ref) => ref.watch(authControllerProvider).valueOrNull?.user,
);
