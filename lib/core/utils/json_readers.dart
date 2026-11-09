/// Tolerant readers for JSON fields (numbers may arrive as int or double,
/// optional fields may be missing or `null`).
abstract final class JsonReaders {
  static int requireInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num) {
      return value.toInt();
    }
    throw FormatException('Missing number "$key".');
  }

  static String requireString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String) {
      return value;
    }
    throw FormatException('Missing text "$key".');
  }

  static int? intOrNull(Object? value) => value is num ? value.toInt() : null;

  static int intOr(Object? value, int fallback) => intOrNull(value) ?? fallback;

  static double doubleOr(Object? value, double fallback) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  static String? stringOrNull(Object? value) => value is String ? value : null;

  static bool boolOr(Object? value, bool fallback) =>
      value is bool ? value : fallback;

  /// An ISO timestamp with offset (`2026-11-15T10:20:30Z`).
  static DateTime? timestamp(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  /// An ISO calendar date (`2026-11-15`) as a local date at midnight.
  static DateTime? date(Object? value) {
    if (value is! String || value.length < 10) {
      return null;
    }
    final parsed = DateTime.tryParse(value.substring(0, 10));
    return parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day);
  }

  static List<Map<String, dynamic>> objectList(Object? value) {
    return value is List
        ? value.whereType<Map<String, dynamic>>().toList()
        : const [];
  }

  static Map<String, dynamic> objectOrEmpty(Object? value) {
    return value is Map<String, dynamic> ? value : const {};
  }
}
