import 'dart:async';

/// In-memory holder for the current access token.
///
/// The auth feature writes it, the [ApiClient] reads it. Keeping it outside
/// the auth state avoids a dependency cycle between the two.
class AccessTokenHolder {
  String? token;
}

/// Broadcasts "the server rejected our token" events (HTTP 401).
class UnauthorizedEvents {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  void notify() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  Future<void> dispose() => _controller.close();
}
