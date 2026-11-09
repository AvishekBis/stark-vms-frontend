import 'dart:async';

import 'package:flutter/foundation.dart';

/// Runs an action only after calls have stopped for [delay].
class Debouncer {
  Debouncer({required this.delay});

  final Duration delay;
  Timer? _timer;

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() => _timer?.cancel();

  void dispose() => cancel();
}
