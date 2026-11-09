import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/utils/dates.dart';
import 'package:stark_vms_frontend/features/documents/presentation/document_providers.dart';

void main() {
  group('Dates.businessToday (Asia/Dhaka, UTC+6)', () {
    test('is the Dhaka date whatever the browser time zone is', () {
      // 17:59 UTC is 23:59 in Dhaka: still the same day.
      expect(
        Dates.businessToday(DateTime.utc(2026, 11, 18, 17, 59)),
        DateTime(2026, 11, 18),
      );
      // 18:00 UTC is midnight in Dhaka: already the next day (BR-08/BR-09).
      expect(
        Dates.businessToday(DateTime.utc(2026, 11, 18, 18)),
        DateTime(2026, 11, 19),
      );
    });
  });

  group('ExpiringDocumentsQueryController.showWithin', () {
    test('a dashboard link always opens the first page of that window', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(
        expiringDocumentsQueryProvider.notifier,
      );

      controller.goToPage(3);
      controller.showWithin(30);

      final query = container.read(expiringDocumentsQueryProvider);
      expect(query.withinDays, 30);
      expect(query.page, 0);

      controller.showWithin(60);
      expect(container.read(expiringDocumentsQueryProvider).withinDays, 60);
    });
  });
}
