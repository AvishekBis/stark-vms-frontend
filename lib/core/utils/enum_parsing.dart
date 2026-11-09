/// Parsing of the API's upper-case enum values (`ACTIVE`, `TAX_TOKEN`, …)
/// into Dart enums. Each enum keeps its own null / fallback rule and calls
/// one of these for the lookup itself.
library;

/// The value of [values] whose [apiValue] equals [raw], or `null` when none
/// does. With [ignoreCase] (URL query parameters) `raw` is upper-cased
/// first.
T? tryParseApiEnum<T extends Enum>(
  List<T> values,
  String Function(T value) apiValue,
  Object? raw, {
  bool ignoreCase = false,
}) {
  final wanted = ignoreCase && raw is String ? raw.toUpperCase() : raw;
  for (final value in values) {
    if (apiValue(value) == wanted) {
      return value;
    }
  }
  return null;
}

/// Like [tryParseApiEnum], but an unknown value is a [FormatException]
/// naming the enum ([name], e.g. `vehicle status`).
T parseApiEnum<T extends Enum>(
  List<T> values,
  String Function(T value) apiValue,
  Object? raw,
  String name,
) {
  return tryParseApiEnum(values, apiValue, raw) ??
      (throw FormatException('Unknown $name: $raw'));
}
