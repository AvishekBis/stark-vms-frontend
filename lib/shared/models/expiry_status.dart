import '../../core/theme/status_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/enum_parsing.dart';

/// BR-08 expiry status, shared by vehicle documents (FR-D02) and driver
/// licences (FR-X02). The server computes it; [compute] mirrors the rule
/// for the rare response that leaves it out.
enum ExpiryStatus {
  valid('VALID', 'Valid'),
  expiringSoon('EXPIRING_SOON', 'Expiring soon'),
  expired('EXPIRED', 'Expired');

  const ExpiryStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// "Expiring soon" means within this many days (inclusive).
  static const int expiringSoonDays = 30;

  StatusTone get tone => switch (this) {
    ExpiryStatus.valid => StatusTone.success,
    ExpiryStatus.expiringSoon => StatusTone.warning,
    ExpiryStatus.expired => StatusTone.danger,
  };

  /// EXPIRED if expiry < today, EXPIRING_SOON if today ≤ expiry ≤ today + 30,
  /// otherwise VALID.
  static ExpiryStatus compute(DateTime expiryDate, DateTime today) {
    final days = Dates.daysBetween(today, expiryDate);
    if (days < 0) {
      return ExpiryStatus.expired;
    }
    if (days <= expiringSoonDays) {
      return ExpiryStatus.expiringSoon;
    }
    return ExpiryStatus.valid;
  }

  /// Parses the API value. A missing or unknown value is computed from
  /// [expiryDate] when given, otherwise it is a [FormatException].
  static ExpiryStatus fromApi(
    Object? raw, {
    DateTime? expiryDate,
    DateTime? today,
  }) {
    final parsed = tryParseApiEnum(values, (status) => status.apiValue, raw);
    if (parsed != null) {
      return parsed;
    }
    if (expiryDate != null) {
      return compute(expiryDate, today ?? Dates.businessToday(DateTime.now()));
    }
    throw FormatException('Unknown expiry status: $raw');
  }

  /// Text for the badge: "Valid", "Expires in 12 days", "Expired 3 days ago".
  String describe(int? daysUntilExpiry) {
    final days = daysUntilExpiry;
    switch (this) {
      case ExpiryStatus.valid:
        return label;
      case ExpiryStatus.expiringSoon:
        if (days == null) {
          return label;
        }
        if (days <= 0) {
          return 'Expires today';
        }
        return days == 1 ? 'Expires tomorrow' : 'Expires in $days days';
      case ExpiryStatus.expired:
        if (days == null || days >= 0) {
          return label;
        }
        return days == -1 ? 'Expired yesterday' : 'Expired ${-days} days ago';
    }
  }
}
