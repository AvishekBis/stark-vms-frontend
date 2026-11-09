import 'dart:async';

import 'package:flutter/foundation.dart';

/// Tracks requests that take longer than [threshold], so the UI can show
/// "Connecting to server…" while a sleeping backend wakes up.
class SlowRequestMonitor extends ChangeNotifier {
  SlowRequestMonitor({required this.threshold});

  final Duration threshold;
  int _slowRequests = 0;
  bool _disposed = false;

  bool get isSlow => _slowRequests > 0;

  /// Runs [request]; flags it as slow if it is still pending after [threshold].
  Future<T> track<T>(Future<T> Function() request) async {
    var flagged = false;
    final timer = Timer(threshold, () {
      flagged = true;
      _slowRequests++;
      _notify();
    });
    try {
      return await request();
    } finally {
      timer.cancel();
      if (flagged) {
        _slowRequests--;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
