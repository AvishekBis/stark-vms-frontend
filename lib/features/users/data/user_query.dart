import '../../../core/network/sort_direction.dart';
import '../../auth/data/auth_models.dart';

export '../../../core/network/sort_direction.dart';

/// Sortable columns of `GET /users?sort=field,direction` (contract 7.3.2).
enum UserSortField {
  email('email', 'E-mail'),
  fullName('fullName', 'Name'),
  createdAt('createdAt', 'Date added');

  const UserSortField(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

const Object _unchanged = Object();

/// Server-side user list parameters. Default sort `email,asc`.
class UserQuery {
  const UserQuery({
    this.page = 0,
    this.size = defaultPageSize,
    this.sortField = UserSortField.email,
    this.sortDirection = SortDirection.ascending,
    this.search = '',
    this.role,
    this.enabled,
  });

  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  static const List<int> pageSizeOptions = [10, 20, 50, 100];

  final int page;
  final int size;
  final UserSortField sortField;
  final SortDirection sortDirection;

  /// Partial, case-insensitive match on e-mail or full name.
  final String search;
  final UserRole? role;

  /// `true` = enabled only, `false` = disabled only, `null` = all.
  final bool? enabled;

  bool get hasFilters => search.isNotEmpty || role != null || enabled != null;

  String get sortParameter => '${sortField.apiValue},${sortDirection.apiValue}';

  Map<String, Object?> toQueryParameters() {
    final trimmedSearch = search.trim();
    return {
      'page': page,
      'size': size.clamp(1, maxPageSize),
      'sort': sortParameter,
      if (trimmedSearch.isNotEmpty) 'search': trimmedSearch,
      if (role != null) 'role': role!.apiValue,
      if (enabled != null) 'enabled': enabled,
    };
  }

  /// [role] and [enabled] accept `null` to clear the filter.
  UserQuery copyWith({
    int? page,
    int? size,
    UserSortField? sortField,
    SortDirection? sortDirection,
    String? search,
    Object? role = _unchanged,
    Object? enabled = _unchanged,
  }) {
    return UserQuery(
      page: page ?? this.page,
      size: size ?? this.size,
      sortField: sortField ?? this.sortField,
      sortDirection: sortDirection ?? this.sortDirection,
      search: search ?? this.search,
      role: identical(role, _unchanged) ? this.role : role as UserRole?,
      enabled: identical(enabled, _unchanged) ? this.enabled : enabled as bool?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is UserQuery &&
        other.page == page &&
        other.size == size &&
        other.sortField == sortField &&
        other.sortDirection == sortDirection &&
        other.search == search &&
        other.role == role &&
        other.enabled == enabled;
  }

  @override
  int get hashCode =>
      Object.hash(page, size, sortField, sortDirection, search, role, enabled);
}
