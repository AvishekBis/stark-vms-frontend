/// Calendar-date helpers (no time of day, no time zone surprises).
abstract final class Dates {
  /// [value] at midnight.
  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// Whole days from [from] to [to] (negative when [to] is earlier).
  static int daysBetween(DateTime from, DateTime to) {
    final start = DateTime.utc(from.year, from.month, from.day);
    final end = DateTime.utc(to.year, to.month, to.day);
    return end.difference(start).inDays;
  }

  static bool isAfterDay(DateTime a, DateTime b) => daysBetween(b, a) > 0;

  /// Asia/Dhaka is UTC+6 all year (no daylight saving time).
  static const Duration businessUtcOffset = Duration(hours: 6);

  /// "Today" in Asia/Dhaka, the server's business time zone (contract 6),
  /// whatever the browser's time zone is.
  static DateTime businessToday(DateTime now) =>
      dateOnly(now.toUtc().add(businessUtcOffset));
}
