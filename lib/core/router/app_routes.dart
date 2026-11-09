/// All URL paths of the app in one place.
abstract final class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String vehicles = '/vehicles';
  static const String newVehicle = '/vehicles/new';
  static const String drivers = '/drivers';
  static const String newDriver = '/drivers/new';
  static const String expiringDocuments = '/documents/expiring';

  /// v2.1 user management - ADMIN only (contract 7.7).
  static const String users = '/users';
  static const String newUser = '/users/new';

  static const String fromParameter = 'from';

  /// `/vehicles?status=MAINTENANCE&type=BUS`.
  static const String statusParameter = 'status';
  static const String typeParameter = 'type';

  /// `/vehicles/12?tab=documents`.
  static const String tabParameter = 'tab';

  /// `/documents/expiring?withinDays=60`.
  static const String withinDaysParameter = 'withinDays';

  static String vehicleDetail(int id, {String? tab}) => tab == null
      ? '/vehicles/$id'
      : Uri(
          path: '/vehicles/$id',
          queryParameters: {tabParameter: tab},
        ).toString();

  static String editVehicle(int id) => '/vehicles/$id/edit';

  /// The vehicle list filtered by API enum values (e.g. `ACTIVE`).
  static String vehiclesFiltered({String? status, String? type}) {
    final parameters = {statusParameter: ?status, typeParameter: ?type};
    return parameters.isEmpty
        ? vehicles
        : Uri(path: vehicles, queryParameters: parameters).toString();
  }

  static String driverDetail(int id) => '/drivers/$id';
  static String editDriver(int id) => '/drivers/$id/edit';

  static String editUser(int id) => '/users/$id/edit';

  /// `true` for `/users` and everything below it (ADMIN-only pages).
  static bool isAdminOnly(String path) =>
      path == users || path.startsWith('$users/');

  static String expiringDocumentsWithin(int days) => Uri(
    path: expiringDocuments,
    queryParameters: {withinDaysParameter: '$days'},
  ).toString();
}
