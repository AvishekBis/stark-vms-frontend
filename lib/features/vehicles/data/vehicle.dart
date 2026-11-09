import 'vehicle_enums.dart';

/// `VehicleResponse` from the API contract.
class Vehicle {
  const Vehicle({
    required this.id,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.status,
    this.brand,
    this.model,
    this.manufactureYear,
    this.color,
    this.fuelType,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.currentDriver,
    this.version = 0,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final vehicleNumber = json['vehicleNumber'];
    if (id is! num || vehicleNumber is! String) {
      throw const FormatException('Vehicle needs an id and a vehicleNumber.');
    }
    return Vehicle(
      id: id.toInt(),
      vehicleNumber: vehicleNumber,
      vehicleType: VehicleType.fromApi(json['vehicleType']),
      status: VehicleStatus.fromApi(
        json['status'] ?? VehicleStatus.active.apiValue,
      ),
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      manufactureYear: (json['manufactureYear'] as num?)?.toInt(),
      color: json['color'] as String?,
      fuelType: FuelType.fromApiOrNull(json['fuelType']),
      createdAt: _parseTimestamp(json['createdAt']),
      updatedAt: _parseTimestamp(json['updatedAt']),
      createdBy: json['createdBy'] as String?,
      currentDriver: DriverSummary.fromJsonOrNull(json['currentDriver']),
      version: (json['version'] as num?)?.toInt() ?? 0,
    );
  }

  final int id;
  final String vehicleNumber;
  final VehicleType vehicleType;
  final VehicleStatus status;
  final String? brand;
  final String? model;
  final int? manufactureYear;
  final String? color;
  final FuelType? fuelType;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  /// v2.0: the driver currently assigned (FR-DR02), `null` when none.
  final DriverSummary? currentDriver;

  /// v2.1 optimistic locking (ADR 0023): the version as loaded. Sent back in
  /// `PUT /vehicles/{id}`; a newer version on the server means 409
  /// `stale-version`.
  final int version;

  /// "Toyota Axio", "Toyota", or `null` when both are missing.
  String? get brandModel {
    final parts = [brand, model]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
  }

  /// BR-05: only an ACTIVE vehicle can get a driver.
  bool get canReceiveDriver => status == VehicleStatus.active;

  /// Moving to [next] ends the current driver assignment: going INACTIVE
  /// from another status unassigns the driver on the server.
  bool endsAssignmentOn(VehicleStatus next) =>
      next == VehicleStatus.inactive && status != VehicleStatus.inactive;

  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicleNumber': vehicleNumber,
    'vehicleType': vehicleType.apiValue,
    'brand': brand,
    'model': model,
    'manufactureYear': manufactureYear,
    'color': color,
    'fuelType': fuelType?.apiValue,
    'status': status.apiValue,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'createdBy': createdBy,
    if (currentDriver != null) 'currentDriver': currentDriver!.toJson(),
    'version': version,
  };

  static DateTime? _parseTimestamp(Object? raw) {
    return raw is String ? DateTime.tryParse(raw) : null;
  }
}

/// `currentDriver` inside a VehicleResponse: `{id, fullName, phone}`.
class DriverSummary {
  const DriverSummary({required this.id, required this.fullName, this.phone});

  static DriverSummary? fromJsonOrNull(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final id = raw['id'];
    if (id is! num) {
      return null;
    }
    return DriverSummary(
      id: id.toInt(),
      fullName: raw['fullName'] as String? ?? '',
      phone: raw['phone'] as String?,
    );
  }

  final int id;
  final String fullName;
  final String? phone;

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'phone': phone,
  };
}

/// `CreateVehicleRequest`; `UpdateVehicleRequest` is the same plus
/// `version` ([toUpdateJson], contract 7.2.2).
class VehicleInput {
  const VehicleInput({
    required this.vehicleNumber,
    required this.vehicleType,
    this.brand,
    this.model,
    this.manufactureYear,
    this.color,
    this.fuelType,
  });

  /// Field names the server may report in `errors[].field`.
  static const Set<String> fieldNames = {
    'vehicleNumber',
    'vehicleType',
    'brand',
    'model',
    'manufactureYear',
    'color',
    'fuelType',
  };

  final String vehicleNumber;
  final VehicleType vehicleType;
  final String? brand;
  final String? model;
  final int? manufactureYear;
  final String? color;
  final FuelType? fuelType;

  /// Trims text and sends blank optional fields as `null`.
  Map<String, dynamic> toJson() => {
    'vehicleNumber': vehicleNumber.trim(),
    'vehicleType': vehicleType.apiValue,
    'brand': _blankToNull(brand),
    'model': _blankToNull(model),
    'manufactureYear': manufactureYear,
    'color': _blankToNull(color),
    'fuelType': fuelType?.apiValue,
  };

  /// `PUT /vehicles/{id}` body: [toJson] plus the loaded [version].
  Map<String, dynamic> toUpdateJson(int version) => {
    ...toJson(),
    'version': version,
  };

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
