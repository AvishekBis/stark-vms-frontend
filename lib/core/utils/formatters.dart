import 'package:intl/intl.dart';

/// Display formatting for dates and numbers.
abstract final class Formatters {
  static final DateFormat _dateTime = DateFormat('d MMM yyyy, HH:mm');
  static final DateFormat _date = DateFormat('d MMM yyyy');
  static final NumberFormat _count = NumberFormat.decimalPattern('en');

  static const String missingValue = '-';

  /// Formats a timestamp in the viewer's local time.
  static String dateTime(DateTime? value) {
    if (value == null) {
      return missingValue;
    }
    return _dateTime.format(value.toLocal());
  }

  static String date(DateTime? value) {
    if (value == null) {
      return missingValue;
    }
    return _date.format(value.toLocal());
  }

  static String count(int value) => _count.format(value);

  static String orMissing(Object? value) {
    if (value == null) {
      return missingValue;
    }
    final text = value.toString().trim();
    return text.isEmpty ? missingValue : text;
  }
}
