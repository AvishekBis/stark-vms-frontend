/// All URL paths of the app in one place.
abstract final class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String vehicles = '/vehicles';
  static const String newVehicle = '/vehicles/new';

  static const String fromParameter = 'from';

  static String vehicleDetail(int id) => '/vehicles/$id';
  static String editVehicle(int id) => '/vehicles/$id/edit';
}
