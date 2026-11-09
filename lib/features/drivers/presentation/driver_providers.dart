import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/page_response.dart';
import '../../../core/utils/change_tracker.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/driver.dart';
import '../data/driver_query.dart';
import '../data/driver_repository.dart';

/// Page / size / sort / search / status of the drivers list; survives
/// navigation, resets when another user logs in.
class DriverQueryController extends Notifier<DriverQuery> {
  @override
  DriverQuery build() {
    ref.watch(currentUserProvider.select((user) => user?.id));
    return const DriverQuery();
  }

  void setSearch(String search) {
    final trimmed = search.trim();
    if (trimmed != state.search) {
      state = state.copyWith(search: trimmed, page: 0);
    }
  }

  void setStatus(DriverStatus? status) {
    if (status != state.status) {
      state = state.copyWith(status: status, page: 0);
    }
  }

  /// Every driver (no search / status filter), first page; sort is kept.
  /// Used by the dashboard "Drivers" card so the list matches its total.
  void clearFilters() {
    final next = state.copyWith(search: '', status: null, page: 0);
    if (next != state) {
      state = next;
    }
  }

  /// Dashboard "Driver licences expiring → View all" (FR-X02): every
  /// driver, soonest licence expiry first.
  void showByLicenceExpiry() {
    final next = state.copyWith(
      search: '',
      status: null,
      page: 0,
      sortField: DriverSortField.licenseExpiry,
      sortDirection: SortDirection.ascending,
    );
    if (next != state) {
      state = next;
    }
  }

  void sortBy(DriverSortField field) {
    state = state.sortField == field
        ? state.copyWith(sortDirection: state.sortDirection.reversed, page: 0)
        : state.copyWith(
            sortField: field,
            sortDirection: SortDirection.ascending,
            page: 0,
          );
  }

  void setSort(DriverSortField field, SortDirection direction) {
    state = state.copyWith(sortField: field, sortDirection: direction, page: 0);
  }

  void goToPage(int page) {
    if (page >= 0 && page != state.page) {
      state = state.copyWith(page: page);
    }
  }

  void setPageSize(int size) {
    state = state.copyWith(
      size: size.clamp(1, DriverQuery.maxPageSize),
      page: 0,
    );
  }
}

final driverQueryProvider =
    NotifierProvider<DriverQueryController, DriverQuery>(
      DriverQueryController.new,
    );

/// The current page of `GET /drivers`.
final driverListProvider = FutureProvider.autoDispose<PageResponse<Driver>>((
  ref,
) {
  ref.watch(driverChangesProvider);
  return ref
      .watch(driverRepositoryProvider)
      .list(ref.watch(driverQueryProvider));
});

/// One driver from `GET /drivers/{id}`.
final driverDetailProvider = FutureProvider.autoDispose.family<Driver, int>((
  ref,
  id,
) {
  ref.watch(driverChangesProvider);
  return ref.watch(driverRepositoryProvider).get(id);
});

/// Driver mutations that are not tied to the form: delete (ADMIN) and
/// deactivate.
class DriverActions {
  const DriverActions(this._ref);

  final Ref<Object?> _ref;

  /// If [driver] was the last row of a page beyond the first, the list
  /// steps back one page (only inspected when the list is loaded).
  Future<void> delete(Driver driver) async {
    await _ref.read(driverRepositoryProvider).delete(driver.id);
    final currentPage = _ref.exists(driverListProvider)
        ? _ref.read(driverListProvider).valueOrNull
        : null;
    if (currentPage != null &&
        currentPage.page > 0 &&
        currentPage.content.length == 1 &&
        currentPage.content.single.id == driver.id) {
      _ref.read(driverQueryProvider.notifier).goToPage(currentPage.page - 1);
    }
    _ref.read(driverChangesProvider.notifier).markChanged();
  }

  /// Sets [driver] INACTIVE (`PUT /drivers/{id}` with the other fields
  /// unchanged and its `version`). The server also ends the current
  /// assignment, so vehicles are refreshed too. On 409 `stale-version` the
  /// drivers are refreshed (so the next try uses the new version) and the
  /// error is rethrown.
  Future<Driver> deactivate(Driver driver) async {
    final Driver updated;
    try {
      updated = await _ref
          .read(driverRepositoryProvider)
          .update(
            driver.id,
            DriverInput(
              fullName: driver.fullName,
              phone: driver.phone,
              licenseNumber: driver.licenseNumber,
              licenseExpiry: driver.licenseExpiry,
              status: DriverStatus.inactive,
            ),
            version: driver.version,
          );
    } on ApiException catch (error) {
      if (error.isStaleVersion) {
        _ref.read(driverChangesProvider.notifier).markChanged();
      }
      rethrow;
    }
    _ref.read(driverChangesProvider.notifier).markChanged();
    _ref.read(vehicleChangesProvider.notifier).markChanged();
    return updated;
  }

  /// `true` when the server refused a delete because the driver has
  /// assignment history (409 `driver-has-history`).
  static bool hasHistory(Object error) =>
      error is ApiException &&
      error.isConflict &&
      (error.type?.endsWith('driver-has-history') ?? false);

  static String deleteErrorMessage(Object error) {
    if (error is ApiException) {
      if (error.isForbidden) {
        return 'Only an administrator can delete drivers.';
      }
      return error.message;
    }
    return 'The driver could not be deleted. Please try again.';
  }
}

final driverActionsProvider = Provider<DriverActions>(
  (ref) => DriverActions(ref),
);
