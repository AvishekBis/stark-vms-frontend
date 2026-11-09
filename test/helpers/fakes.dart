import 'package:stark_vms_frontend/core/network/api_exception.dart';
import 'package:stark_vms_frontend/core/network/page_response.dart';
import 'package:stark_vms_frontend/features/auth/data/auth_models.dart';
import 'package:stark_vms_frontend/features/auth/data/auth_repository.dart';
import 'package:stark_vms_frontend/features/auth/presentation/auth_controller.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_enums.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_query.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_repository.dart';

/// Test-only data and fakes. Production code never contains vehicle data
/// (FR-V06).
const User adminUser = User(
  id: 1,
  email: 'admin@stark.local',
  fullName: 'Fleet Admin',
  role: UserRole.admin,
);

const User staffUser = User(
  id: 2,
  email: 'staff@stark.local',
  fullName: 'Fleet Officer',
  role: UserRole.staff,
);

AuthSession sessionFor(User user) {
  return AuthSession(
    accessToken: 'test-token',
    expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    user: user,
  );
}

Vehicle testVehicle({
  int id = 1,
  String vehicleNumber = 'DHK-1234',
  VehicleType vehicleType = VehicleType.car,
  VehicleStatus status = VehicleStatus.active,
  String? brand = 'Toyota',
  String? model = 'Axio',
  int? manufactureYear = 2019,
  DriverSummary? currentDriver,
  int version = 0,
}) {
  return Vehicle(
    id: id,
    vehicleNumber: vehicleNumber,
    vehicleType: vehicleType,
    status: status,
    brand: brand,
    model: model,
    manufactureYear: manufactureYear,
    color: 'White',
    fuelType: FuelType.octane,
    createdAt: DateTime.utc(2026, 11, 6, 9, 15),
    updatedAt: DateTime.utc(2026, 11, 6, 9, 15),
    createdBy: 'admin@stark.local',
    currentDriver: currentDriver,
    version: version,
  );
}

/// Auth controller frozen in a given state (no storage, no timers).
class FakeAuthController extends AuthController {
  FakeAuthController(this.initialState);

  final AuthState initialState;

  @override
  Future<AuthState> build() async => initialState;
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.loginError,
    this.loginResponse,
    this.changePasswordError,
    this.loginErrorAfterPasswordChange,
  });

  final ApiException? loginError;
  final LoginResponse? loginResponse;
  int loginCalls = 0;

  /// Every login as (email, password).
  final List<(String, String)> logins = [];

  /// v2.1 `PUT /auth/me/password`: fails with this error when set.
  ApiException? changePasswordError;

  /// The re-login after a password change fails with this error when set.
  ApiException? loginErrorAfterPasswordChange;

  /// Every accepted change as (currentPassword, newPassword).
  final List<(String, String)> passwordChanges = [];

  /// Called inside every login (e.g. to fire a 401 event meanwhile).
  void Function()? onLogin;

  /// The token handed out after a password change (to tell sessions apart).
  static const String tokenAfterPasswordChange = 'token-after-change';

  @override
  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    logins.add((email, password));
    onLogin?.call();
    final error = passwordChanges.isEmpty
        ? loginError
        : loginErrorAfterPasswordChange;
    if (error != null) {
      throw error;
    }
    final response =
        loginResponse ??
        const LoginResponse(
          accessToken: 'test-token',
          tokenType: 'Bearer',
          expiresIn: Duration(hours: 1),
          user: adminUser,
        );
    if (passwordChanges.isEmpty) {
      return response;
    }
    return LoginResponse(
      accessToken: tokenAfterPasswordChange,
      tokenType: response.tokenType,
      expiresIn: response.expiresIn,
      user: response.user,
    );
  }

  @override
  Future<User> currentUser() async => loginResponse?.user ?? adminUser;

  @override
  Future<void> changeOwnPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final error = changePasswordError;
    if (error != null) {
      throw error;
    }
    passwordChanges.add((currentPassword, newPassword));
  }
}

/// In-memory vehicle repository with optional forced failures.
class FakeVehicleRepository implements VehicleRepository {
  FakeVehicleRepository({List<Vehicle> seed = const [], this.saveError})
    : vehicles = [...seed];

  final List<Vehicle> vehicles;
  ApiException? saveError;
  final List<VehicleQuery> listQueries = [];

  /// The `version` sent with every update (contract 7.2.2).
  final List<int> updateVersions = [];

  @override
  Future<PageResponse<Vehicle>> list(VehicleQuery query) async {
    listQueries.add(query);
    final matches = vehicles
        .where(
          (v) => v.vehicleNumber.toLowerCase().contains(
            query.search.toLowerCase(),
          ),
        )
        .where((v) => query.status == null || v.status == query.status)
        .where((v) => query.type == null || v.vehicleType == query.type)
        .toList();
    final start = query.page * query.size;
    final pageItems = matches.skip(start).take(query.size).toList();
    return PageResponse(
      content: pageItems,
      page: query.page,
      size: query.size,
      totalElements: matches.length,
      totalPages: (matches.length / query.size).ceil(),
    );
  }

  @override
  Future<Vehicle> get(int id) async {
    return vehicles.firstWhere(
      (v) => v.id == id,
      orElse: () => throw ApiException.fromProblemDetails({'status': 404}),
    );
  }

  @override
  Future<Vehicle> create(VehicleInput input) async {
    final error = saveError;
    if (error != null) {
      throw error;
    }
    final created = testVehicle(
      id: vehicles.length + 1,
      vehicleNumber: input.vehicleNumber,
      vehicleType: input.vehicleType,
    );
    vehicles.add(created);
    return created;
  }

  @override
  Future<Vehicle> update(
    int id,
    VehicleInput input, {
    required int version,
  }) async {
    updateVersions.add(version);
    final error = saveError;
    if (error != null) {
      throw error;
    }
    final updated = testVehicle(
      id: id,
      vehicleNumber: input.vehicleNumber,
      version: version + 1,
    );
    vehicles[vehicles.indexWhere((v) => v.id == id)] = updated;
    return updated;
  }

  /// When set, delete fails with this error (e.g. 409 vehicle-has-history).
  ApiException? deleteError;
  final List<(int, VehicleStatus)> statusChanges = [];

  @override
  Future<void> delete(int id) async {
    final error = deleteError;
    if (error != null) {
      throw error;
    }
    vehicles.removeWhere((v) => v.id == id);
  }

  @override
  Future<Vehicle> changeStatus(int id, VehicleStatus status) async {
    statusChanges.add((id, status));
    final index = vehicles.indexWhere((v) => v.id == id);
    final old = vehicles[index];
    final updated = testVehicle(
      id: id,
      vehicleNumber: old.vehicleNumber,
      status: status,
      currentDriver: status == VehicleStatus.inactive
          ? null
          : old.currentDriver,
    );
    vehicles[index] = updated;
    return updated;
  }
}
