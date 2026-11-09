import '../../../core/network/sort_direction.dart';
import 'vehicle_enums.dart';

export '../../../core/network/sort_direction.dart';

/// Sortable columns allowed by `GET /vehicles?sort=field,direction`.
enum VehicleSortField {
  vehicleNumber('vehicleNumber', 'Vehicle number'),
  manufactureYear('manufactureYear', 'Year'),
  createdAt('createdAt', 'Date added');

  const VehicleSortField(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

const Object _unchanged = Object();

/// Server-side list parameters: page, size, sort, search and the v2.0
/// `status` / `type` filters (FR-V08, FR-V09).
class VehicleQuery {
  const VehicleQuery({
    this.page = 0,
    this.size = defaultPageSize,
    this.sortField = VehicleSortField.createdAt,
    this.sortDirection = SortDirection.descending,
    this.search = '',
    this.status,
    this.type,
  });

  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  static const List<int> pageSizeOptions = [10, 20, 50, 100];

  /// Zero-based page index.
  final int page;
  final int size;
  final VehicleSortField sortField;
  final SortDirection sortDirection;
  final String search;

  /// `null` = all statuses / all types.
  final VehicleStatus? status;
  final VehicleType? type;

  String get sortParameter => '${sortField.apiValue},${sortDirection.apiValue}';

  bool get hasFilters => status != null || type != null;

  Map<String, Object?> toQueryParameters() {
    final trimmedSearch = search.trim();
    return {
      'page': page,
      'size': size.clamp(1, maxPageSize),
      'sort': sortParameter,
      if (trimmedSearch.isNotEmpty) 'search': trimmedSearch,
      if (status != null) 'status': status!.apiValue,
      if (type != null) 'type': type!.apiValue,
    };
  }

  /// [status] and [type] accept `null` to clear the filter; leave them out
  /// to keep the current value.
  VehicleQuery copyWith({
    int? page,
    int? size,
    VehicleSortField? sortField,
    SortDirection? sortDirection,
    String? search,
    Object? status = _unchanged,
    Object? type = _unchanged,
  }) {
    return VehicleQuery(
      page: page ?? this.page,
      size: size ?? this.size,
      sortField: sortField ?? this.sortField,
      sortDirection: sortDirection ?? this.sortDirection,
      search: search ?? this.search,
      status: identical(status, _unchanged)
          ? this.status
          : status as VehicleStatus?,
      type: identical(type, _unchanged) ? this.type : type as VehicleType?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is VehicleQuery &&
        other.page == page &&
        other.size == size &&
        other.sortField == sortField &&
        other.sortDirection == sortDirection &&
        other.search == search &&
        other.status == status &&
        other.type == type;
  }

  @override
  int get hashCode =>
      Object.hash(page, size, sortField, sortDirection, search, status, type);
}
