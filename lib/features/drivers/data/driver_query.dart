import '../../../core/network/sort_direction.dart';
import 'driver.dart';

export '../../../core/network/sort_direction.dart';

/// Sortable columns of `GET /drivers?sort=field,direction`.
enum DriverSortField {
  fullName('fullName', 'Name'),
  licenseExpiry('licenseExpiry', 'Licence expiry'),
  createdAt('createdAt', 'Date added');

  const DriverSortField(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

const Object _unchanged = Object();

/// Server-side driver list parameters (contract 6.3).
class DriverQuery {
  const DriverQuery({
    this.page = 0,
    this.size = defaultPageSize,
    this.sortField = DriverSortField.fullName,
    this.sortDirection = SortDirection.ascending,
    this.search = '',
    this.status,
    this.available,
  });

  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  static const List<int> pageSizeOptions = [10, 20, 50, 100];

  final int page;
  final int size;
  final DriverSortField sortField;
  final SortDirection sortDirection;
  final String search;
  final DriverStatus? status;

  /// `true` → only ACTIVE drivers without a current vehicle (assign dialog).
  final bool? available;

  String get sortParameter => '${sortField.apiValue},${sortDirection.apiValue}';

  Map<String, Object?> toQueryParameters() {
    final trimmedSearch = search.trim();
    return {
      'page': page,
      'size': size.clamp(1, maxPageSize),
      'sort': sortParameter,
      if (trimmedSearch.isNotEmpty) 'search': trimmedSearch,
      if (status != null) 'status': status!.apiValue,
      if (available != null) 'available': available,
    };
  }

  /// [status] and [available] accept `null` to clear the filter.
  DriverQuery copyWith({
    int? page,
    int? size,
    DriverSortField? sortField,
    SortDirection? sortDirection,
    String? search,
    Object? status = _unchanged,
    Object? available = _unchanged,
  }) {
    return DriverQuery(
      page: page ?? this.page,
      size: size ?? this.size,
      sortField: sortField ?? this.sortField,
      sortDirection: sortDirection ?? this.sortDirection,
      search: search ?? this.search,
      status: identical(status, _unchanged)
          ? this.status
          : status as DriverStatus?,
      available: identical(available, _unchanged)
          ? this.available
          : available as bool?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DriverQuery &&
        other.page == page &&
        other.size == size &&
        other.sortField == sortField &&
        other.sortDirection == sortDirection &&
        other.search == search &&
        other.status == status &&
        other.available == available;
  }

  @override
  int get hashCode => Object.hash(
    page,
    size,
    sortField,
    sortDirection,
    search,
    status,
    available,
  );
}
