import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/theme/status_colors.dart';
import 'package:stark_vms_frontend/shared/models/expiry_status.dart';

void main() {
  group('ExpiryStatus.fromApi', () {
    test('parses the three API values', () {
      expect(ExpiryStatus.fromApi('VALID'), ExpiryStatus.valid);
      expect(ExpiryStatus.fromApi('EXPIRING_SOON'), ExpiryStatus.expiringSoon);
      expect(ExpiryStatus.fromApi('EXPIRED'), ExpiryStatus.expired);
    });

    test('computes a missing value from the expiry date', () {
      final today = DateTime(2026, 11, 18);
      expect(
        ExpiryStatus.fromApi(
          null,
          expiryDate: DateTime(2026, 11, 17),
          today: today,
        ),
        ExpiryStatus.expired,
      );
    });

    test('an unknown value without a date is a FormatException', () {
      expect(() => ExpiryStatus.fromApi('SOON'), throwsFormatException);
    });
  });

  group('ExpiryStatus.compute (BR-08)', () {
    final today = DateTime(2026, 11, 18);

    test('TC-08: expiring in 10 days is EXPIRING_SOON', () {
      expect(
        ExpiryStatus.compute(DateTime(2026, 11, 28), today),
        ExpiryStatus.expiringSoon,
      );
    });

    test('TC-09: expired yesterday is EXPIRED', () {
      expect(
        ExpiryStatus.compute(DateTime(2026, 11, 17), today),
        ExpiryStatus.expired,
      );
    });

    test('today and today + 30 are EXPIRING_SOON, day 31 is VALID', () {
      expect(ExpiryStatus.compute(today, today), ExpiryStatus.expiringSoon);
      expect(
        ExpiryStatus.compute(DateTime(2026, 12, 18), today),
        ExpiryStatus.expiringSoon,
      );
      expect(
        ExpiryStatus.compute(DateTime(2026, 12, 19), today),
        ExpiryStatus.valid,
      );
    });
  });

  group('describe and tone', () {
    test('badge text always says what it means', () {
      expect(ExpiryStatus.valid.describe(147), 'Valid');
      expect(ExpiryStatus.expiringSoon.describe(12), 'Expires in 12 days');
      expect(ExpiryStatus.expiringSoon.describe(1), 'Expires tomorrow');
      expect(ExpiryStatus.expiringSoon.describe(0), 'Expires today');
      expect(ExpiryStatus.expired.describe(-3), 'Expired 3 days ago');
      expect(ExpiryStatus.expired.describe(-1), 'Expired yesterday');
      expect(ExpiryStatus.expired.describe(null), 'Expired');
    });

    test('green / amber / red tones', () {
      expect(ExpiryStatus.valid.tone, StatusTone.success);
      expect(ExpiryStatus.expiringSoon.tone, StatusTone.warning);
      expect(ExpiryStatus.expired.tone, StatusTone.danger);
    });
  });
}
