import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/theme/app_palette.dart';
import 'package:stark_vms_frontend/core/theme/app_theme.dart';
import 'package:stark_vms_frontend/shared/models/expiry_status.dart';
import 'package:stark_vms_frontend/shared/widgets/expiry_badge.dart';

void main() {
  const cases = [
    (ExpiryStatus.valid, 147, 'Valid', AppPalette.green),
    (ExpiryStatus.expiringSoon, 12, 'Expires in 12 days', AppPalette.amber),
    (ExpiryStatus.expired, -3, 'Expired 3 days ago', AppPalette.red),
  ];

  for (final (status, days, text, color) in cases) {
    testWidgets('ExpiryBadge ${status.apiValue}: "$text" on its colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: ExpiryBadge(status: status, daysUntilExpiry: days),
            ),
          ),
        ),
      );

      expect(find.text(text), findsOneWidget);
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(ExpiryBadge),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect((box.decoration as BoxDecoration).color, color);
    });
  }

  test('every expiry status is covered', () {
    expect(cases.map((c) => c.$1), containsAll(ExpiryStatus.values));
  });
}
