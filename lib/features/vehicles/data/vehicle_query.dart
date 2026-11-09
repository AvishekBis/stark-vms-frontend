/// Sortable columns allowed by `GET /vehicles?sort=field,direction`.
enum VehicleSortField {
  vehicleNumber('vehicleNumber', 'Vehicle number'),
  manufactureYear('manufactureYear', 'Year'),
  createdAt('createdAt', 'Date added');

  const VehicleSortField(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

enum SortDirection {
  ascending('asc'),
  descending('desc');

  const SortDirection(this.apiValue);

  final String apiValue;

  SortDirection get reversed => this == SortDirection.ascending
      ? SortDirection.descending
      : SortDirection.ascending;
}

/// Server-side list parameters: page, size, sort and search.
///
/// v2.0 adds `status` and `type` filters here without changing callers.
class VehicleQuery {
  const VehicleQuery({
    this.page = 0,
    this.size = defaultPageSize,
    this.sortField = VehicleSortField.createdAt,
    this.sortDirection = SortDirection.descending,
    this.search = '',
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

  String get sortParameter => '${sortField.apiValue},${sortDirection.apiValue}';

  Map<String, Object?> toQueryParameters() {
    final trimmedSearch = search.trim();
    return {
      'page': page,
      'size': size.clamp(1, maxPageSize),
      'sort': sortParameter,
      if (trimmedSearch.isNotEmpty) 'search': trimmedSearch,
    };
  }

  VehicleQuery copyWith({
    int? page,
    int? size,
    VehicleSortField? sortField,
    SortDirection? sortDirection,
    String? search,
  }) {
    return VehicleQuery(
      page: page ?? this.page,
      size: size ?? this.size,
      sortField: sortField ?? this.sortField,
      sortDirection: sortDirection ?? this.sortDirection,
      search: search ?? this.search,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is VehicleQuery &&
        other.page == page &&
        other.size == size &&
        other.sortField == sortField &&
        other.sortDirection == sortDirection &&
        other.search == search;
  }

  @override
  int get hashCode => Object.hash(page, size, sortField, sortDirection, search);
}
