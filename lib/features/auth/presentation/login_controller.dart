import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import 'auth_controller.dart';

/// Submission state of the login form: idle, loading, or failed with a
/// message that is safe to show.
class LoginController extends AutoDisposeAsyncNotifier<void> {
  static const String invalidCredentialsMessage = 'Invalid email or password.';

  @override
  Future<void> build() async {}

  Future<void> submit({required String email, required String password}) async {
    if (state.isLoading) {
      return;
    }
    state = const AsyncLoading();
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(email: email, password: password);
      state = const AsyncData(null);
    } on ApiException catch (error, stackTrace) {
      state = AsyncError(_messageFor(error), stackTrace);
    } on FormatException catch (_, stackTrace) {
      state = AsyncError('The server sent an unexpected response.', stackTrace);
    }
  }

  /// 401 → the generic credentials message. 429 (v1.1, ADR 0022) → the
  /// server `detail` ("Too many failed login attempts. Try again in N
  /// minutes."), never "invalid credentials". Anything else → its message.
  static String _messageFor(ApiException error) {
    if (error.isUnauthorized) {
      return invalidCredentialsMessage;
    }
    return error.message;
  }
}

final loginControllerProvider =
    AsyncNotifierProvider.autoDispose<LoginController, void>(
      LoginController.new,
    );
