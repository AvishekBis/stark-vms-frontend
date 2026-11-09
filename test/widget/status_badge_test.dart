import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/theme/app_palette.dart';
import 'package:stark_vms_frontend/core/theme/app_theme.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_enums.dart';
import 'package:stark_vms_frontend/features/vehicles/presentation/widgets/vehicle_status_badge.dart';

void main() {
  const expectations = {
    VehicleStatus.active: ('Active', AppPalette.green),
    VehicleStatus.maintenance: ('Maintenance', AppPalette.amber),
    VehicleStatus.inactive: ('Inactive', AppPalette.grey),
  };

  for (final MapEntry(key: status, value: (label, color))
      in expectations.entries) {
    testWidgets(
      'VehicleStatusBadge shows text and colour for ${status.apiValue}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Center(child: VehicleStatusBadge(status: status)),
            ),
          ),
        );

        expect(find.text(label), findsOneWidget);
        final box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(VehicleStatusBadge),
            matching: find.byType(DecoratedBox),
          ),
        );
        expect((box.decoration as BoxDecoration).color, color);
      },
    );
  }

  test('every status has a badge mapping', () {
    expect(expectations.keys, containsAll(VehicleStatus.values));
  });
}
