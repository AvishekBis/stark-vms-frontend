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
  FakeAuthRepository({this.loginError, this.loginResponse});

  final ApiException? loginError;
  final LoginResponse? loginResponse;
  int loginCalls = 0;

  @override
  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    final error = loginError;
    if (error != null) {
      throw error;
    }
    return loginResponse ??
        const LoginResponse(
          accessToken: 'test-token',
          tokenType: 'Bearer',
          expiresIn: Duration(hours: 1),
          user: adminUser,
        );
  }

  @override
  Future<User> currentUser() async => loginResponse?.user ?? adminUser;
}

/// In-memory vehicle repository with optional forced failures.
class FakeVehicleRepository implements VehicleRepository {
  FakeVehicleRepository({List<Vehicle> seed = const [], this.saveError})
    : vehicles = [...seed];

  final List<Vehicle> vehicles;
  ApiException? saveError;
  final List<VehicleQuery> listQueries = [];

  /// The `version` sent with every update (contract 6.2).
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

  @override
  Future<void> delete(int id) async {
    vehicles.removeWhere((v) => v.id == id);
  }
}
