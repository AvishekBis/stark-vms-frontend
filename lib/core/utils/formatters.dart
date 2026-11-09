import 'package:intl/intl.dart';

/// Display formatting for dates and numbers.
abstract final class Formatters {
  static final DateFormat _dateTime = DateFormat('d MMM yyyy, HH:mm');
  static final DateFormat _date = DateFormat('d MMM yyyy');
  static final NumberFormat _count = NumberFormat.decimalPattern('en');
  static final DateFormat _isoDate = DateFormat('yyyy-MM-dd');
  static final DateFormat _month = DateFormat('MMMM yyyy');
  static final NumberFormat _money = NumberFormat('#,##0.00', 'en');
  static final NumberFormat _oneDecimal = NumberFormat('#,##0.#', 'en');

  /// Currency code shown in front of every amount (all costs are BDT).
  static const String currency = 'BDT';

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

  /// `3500` → `BDT 3,500.00`.
  static String money(num? value) {
    if (value == null) {
      return missingValue;
    }
    return '$currency ${_money.format(value)}';
  }

  /// The calendar date as the API expects it: `2026-11-15`.
  static String isoDate(DateTime value) => _isoDate.format(value);

  /// `2026-11` → `November 2026`; unknown text is returned unchanged.
  static String month(String? yearMonth) {
    if (yearMonth == null || yearMonth.trim().isEmpty) {
      return missingValue;
    }
    final parsed = DateTime.tryParse('${yearMonth.trim()}-01');
    return parsed == null ? yearMonth : _month.format(parsed);
  }

  /// `182344` → `178.1 KB`.
  static String fileSize(int? bytes) {
    if (bytes == null || bytes < 0) {
      return missingValue;
    }
    const kb = 1024;
    const mb = kb * 1024;
    if (bytes >= mb) {
      return '${_oneDecimal.format(bytes / mb)} MB';
    }
    if (bytes >= kb) {
      return '${_oneDecimal.format(bytes / kb)} KB';
    }
    return '$bytes B';
  }

  /// Audit line (FR-X01): `Added 6 Nov 2026, 09:15 by admin@stark.local`.
  /// [verb] is e.g. "Added" or "Uploaded"; missing parts are left out.
  static String audit(String verb, {DateTime? at, String? by}) {
    final who = by?.trim();
    return [
      verb,
      if (at != null) dateTime(at),
      if (who != null && who.isNotEmpty) 'by $who',
    ].join(' ');
  }

  static String orMissing(Object? value) {
    if (value == null) {
      return missingValue;
    }
    final text = value.toString().trim();
    return text.isEmpty ? missingValue : text;
  }
}
