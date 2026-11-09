import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/features/auth/presentation/auth_controller.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_query.dart';
import 'package:stark_vms_frontend/features/vehicles/presentation/vehicle_providers.dart';

import '../helpers/fakes.dart';

void main() {
  group('VehicleQuery.toQueryParameters', () {
    test('defaults to page 0, size 20, newest first', () {
      expect(const VehicleQuery().toQueryParameters(), {
        'page': 0,
        'size': 20,
        'sort': 'createdAt,desc',
      });
    });

    test('adds a trimmed search and caps the size at 100', () {
      const query = VehicleQuery(
        page: 2,
        size: 500,
        sortField: VehicleSortField.vehicleNumber,
        sortDirection: SortDirection.ascending,
        search: '  dhk ',
      );
      expect(query.toQueryParameters(), {
        'page': 2,
        'size': 100,
        'sort': 'vehicleNumber,asc',
        'search': 'dhk',
      });
    });
  });

  group('VehicleQueryController', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(AuthState.signedIn(sessionFor(staffUser))),
          ),
        ],
      );
    });
    tearDown(() => container.dispose());

    VehicleQuery read() => container.read(vehicleQueryProvider);
    VehicleQueryController controller() =>
        container.read(vehicleQueryProvider.notifier);

    test('a new search goes back to the first page', () {
      controller().goToPage(3);
      controller().setSearch('DHK');
      expect(read().page, 0);
      expect(read().search, 'DHK');
    });

    test('tapping the same column flips the direction, a new column starts ascending', () {
      controller().sortBy(VehicleSortField.createdAt);
      expect(read().sortDirection, SortDirection.ascending);
      controller().sortBy(VehicleSortField.createdAt);
      expect(read().sortDirection, SortDirection.descending);
      controller().sortBy(VehicleSortField.manufactureYear);
      expect(read().sortField, VehicleSortField.manufactureYear);
      expect(read().sortDirection, SortDirection.ascending);
    });

    test('changing the page size resets the page', () {
      controller().goToPage(2);
      controller().setPageSize(50);
      expect(read().size, 50);
      expect(read().page, 0);
    });
  });
}
