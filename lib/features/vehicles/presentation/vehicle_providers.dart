import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/page_response.dart';
import '../../../core/utils/change_tracker.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/vehicle.dart';
import '../data/vehicle_enums.dart';
import '../data/vehicle_query.dart';
import '../data/vehicle_repository.dart';

/// Current page / size / sort / search / filters of the vehicle list. Not auto-disposed,
/// so it survives navigating away and back; it resets when another user
/// logs in.
class VehicleQueryController extends Notifier<VehicleQuery> {
  @override
  VehicleQuery build() {
    ref.watch(currentUserProvider.select((user) => user?.id));
    return const VehicleQuery();
  }

  void setSearch(String search) {
    final trimmed = search.trim();
    if (trimmed != state.search) {
      state = state.copyWith(search: trimmed, page: 0);
    }
  }

  /// Any filter change starts again at the first page (FR-V09).
  void setStatus(VehicleStatus? status) {
    if (status != state.status) {
      state = state.copyWith(status: status, page: 0);
    }
  }

  void setType(VehicleType? type) {
    if (type != state.type) {
      state = state.copyWith(type: type, page: 0);
    }
  }

  /// Shows exactly these filters (used by dashboard links and
  /// `/vehicles?status=…&type=…`); search is cleared, sort is kept.
  void showOnly({VehicleStatus? status, VehicleType? type}) {
    final next = state.copyWith(
      status: status,
      type: type,
      search: '',
      page: 0,
    );
    if (next != state) {
      state = next;
    }
  }

  void clearFilters() => showOnly();

  /// Tapping the active column flips the direction; a new column starts
  /// ascending.
  void sortBy(VehicleSortField field) {
    state = state.sortField == field
        ? state.copyWith(sortDirection: state.sortDirection.reversed, page: 0)
        : state.copyWith(
            sortField: field,
            sortDirection: SortDirection.ascending,
            page: 0,
          );
  }

  void setSort(VehicleSortField field, SortDirection direction) {
    state = state.copyWith(sortField: field, sortDirection: direction, page: 0);
  }

  void goToPage(int page) {
    if (page >= 0 && page != state.page) {
      state = state.copyWith(page: page);
    }
  }

  void setPageSize(int size) {
    state = state.copyWith(
      size: size.clamp(1, VehicleQuery.maxPageSize),
      page: 0,
    );
  }
}

final vehicleQueryProvider =
    NotifierProvider<VehicleQueryController, VehicleQuery>(
      VehicleQueryController.new,
    );

/// The current page of vehicles from `GET /vehicles`.
final vehicleListProvider = FutureProvider.autoDispose<PageResponse<Vehicle>>((
  ref,
) {
  ref.watch(vehicleChangesProvider);
  final query = ref.watch(vehicleQueryProvider);
  return ref.watch(vehicleRepositoryProvider).list(query);
});

/// One vehicle from `GET /vehicles/{id}`. Refreshed explicitly after an
/// update (it does not watch [vehicleChangesProvider], so a deleted vehicle
/// is not re-fetched while its page is closing).
final vehicleDetailProvider = FutureProvider.autoDispose.family<Vehicle, int>((
  ref,
  id,
) {
  return ref.watch(vehicleRepositoryProvider).get(id);
});

/// Mutations that are not tied to the form: delete and status change.
class VehicleActions {
  const VehicleActions(this._ref);

  final Ref<Object?> _ref;

  /// Deletes [vehicle] (ADMIN only). If it was the last row of a page beyond
  /// the first, the list steps back one page. The list is only inspected when
  /// it is already loaded, so deleting from the detail page does not fetch it.
  Future<void> delete(Vehicle vehicle) async {
    await _ref.read(vehicleRepositoryProvider).delete(vehicle.id);
    final currentPage = _ref.exists(vehicleListProvider)
        ? _ref.read(vehicleListProvider).valueOrNull
        : null;
    if (currentPage != null && _isLastRowOfLaterPage(currentPage, vehicle)) {
      _ref.read(vehicleQueryProvider.notifier).goToPage(currentPage.page - 1);
    }
    _ref.read(vehicleChangesProvider.notifier).markChanged();
  }

  static bool _isLastRowOfLaterPage(
    PageResponse<Vehicle> page,
    Vehicle vehicle,
  ) {
    return page.page > 0 &&
        page.content.length == 1 &&
        page.content.single.id == vehicle.id;
  }

  /// `PATCH /vehicles/{id}/status` (ADMIN, FR-V07). INACTIVE also ends the
  /// current driver assignment, so drivers are refreshed too.
  Future<Vehicle> changeStatus(Vehicle vehicle, VehicleStatus status) async {
    final updated = await _ref
        .read(vehicleRepositoryProvider)
        .changeStatus(vehicle.id, status);
    _ref.read(vehicleChangesProvider.notifier).markChanged();
    _ref.read(driverChangesProvider.notifier).markChanged();
    _ref.invalidate(vehicleDetailProvider(vehicle.id));
    return updated;
  }

  static String statusErrorMessage(Object error) {
    if (error is ApiException) {
      return error.isForbidden
          ? 'Only an administrator can change the vehicle status.'
          : error.message;
    }
    return 'The status could not be changed. Please try again.';
  }

  /// `true` when the server refused a delete because of BR-10.
  static bool hasHistory(Object error) =>
      error is ApiException &&
      error.isConflict &&
      (error.type?.endsWith('vehicle-has-history') ?? false);

  /// A message for a failed delete that the UI can show as is.
  static String deleteErrorMessage(Object error) {
    if (error is ApiException) {
      if (error.isForbidden) {
        return 'Only an administrator can delete vehicles.';
      }
      return error.message;
    }
    return 'The vehicle could not be deleted. Please try again.';
  }
}

final vehicleActionsProvider = Provider<VehicleActions>(
  (ref) => VehicleActions(ref),
);
