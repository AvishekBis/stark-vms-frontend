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

  /// v1.1 optimistic locking (ADR 0023): the version as loaded. Sent back in
  /// `PUT /vehicles/{id}`; a newer version on the server means 409
  /// `stale-version`. A missing value reads as 0 (a new vehicle).
  final int version;

  /// "Toyota Axio", "Toyota", or `null` when both are missing.
  String? get brandModel {
    final parts = [brand, model]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
  }

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
    'version': version,
  };

  static DateTime? _parseTimestamp(Object? raw) {
    return raw is String ? DateTime.tryParse(raw) : null;
  }
}

/// The editable vehicle fields: [toJson] is the `CreateVehicleRequest` body
/// (never with a `version`), [toUpdateJson] the `UpdateVehicleRequest` body,
/// which also requires the loaded `version` (contract 6.2).
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
