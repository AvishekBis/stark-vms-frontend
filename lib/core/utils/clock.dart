import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Source of "now", injectable so time-based logic (session expiry, year
/// bounds, and in v2.0 document expiry) is testable with a fixed time.
class Clock {
  const Clock();

  DateTime now() => DateTime.now();
}

/// A clock frozen at [fixedNow]; used in tests.
class FixedClock extends Clock {
  const FixedClock(this.fixedNow);

  final DateTime fixedNow;

  @override
  DateTime now() => fixedNow;
}

final clockProvider = Provider<Clock>((ref) => const Clock());
