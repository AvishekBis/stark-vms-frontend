import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_query.dart';
import 'package:stark_vms_frontend/shared/widgets/row_actions.dart';
import 'package:stark_vms_frontend/shared/widgets/sort_menu.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets('SortMenu shows arrow icons, not arrow characters', (
    tester,
  ) async {
    (VehicleSortField, SortDirection)? chosen;
    await pump(
      tester,
      SortMenu<VehicleSortField>(
        key: const Key('sortMenu'),
        values: VehicleSortField.values,
        label: (field) => field.label,
        field: VehicleSortField.createdAt,
        direction: SortDirection.descending,
        onSelected: (field, direction) => chosen = (field, direction),
      ),
    );

    expect(find.text('Date added'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.textContaining('↓'), findsNothing);
    expect(find.textContaining('↑'), findsNothing);

    await tester.tap(find.byKey(const Key('sortMenu')));
    await tester.pumpAndSettle();
    // Every field in both directions, plus the chip itself.
    expect(find.byIcon(Icons.arrow_upward), findsNWidgets(3));
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Icon && widget.semanticLabel == 'ascending',
      ),
      findsNWidgets(3),
    );

    await tester.tap(find.text('Year').first);
    await tester.pumpAndSettle();
    expect(chosen, (VehicleSortField.manufactureYear, SortDirection.ascending));
  });

  testWidgets('RowActions keeps the prefix.edit.id / prefix.delete.id keys', (
    tester,
  ) async {
    var edits = 0;
    var deletes = 0;
    Widget actions({required bool isAdmin}) => RowActions(
      keyPrefix: 'vehicle',
      id: 7,
      isAdmin: isAdmin,
      onEdit: () => edits++,
      onDelete: () => deletes++,
    );

    await pump(tester, actions(isAdmin: false));
    expect(find.byKey(const ValueKey('vehicle.edit.7')), findsOneWidget);
    expect(find.byKey(const ValueKey('vehicle.delete.7')), findsNothing);

    await pump(tester, actions(isAdmin: true));
    await tester.tap(find.byKey(const ValueKey('vehicle.edit.7')));
    await tester.tap(find.byKey(const ValueKey('vehicle.delete.7')));
    expect((edits, deletes), (1, 1));
  });
}
