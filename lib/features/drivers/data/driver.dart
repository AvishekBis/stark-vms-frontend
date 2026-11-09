import '../../../core/utils/enum_parsing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json_readers.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/models/expiry_status.dart';

/// `DriverStatus` (contract 6.3).
enum DriverStatus {
  active('ACTIVE', 'Active'),
  inactive('INACTIVE', 'Inactive');

  const DriverStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// Unknown values are a [FormatException]; `null` means the default ACTIVE.
  static DriverStatus fromApi(Object? raw) {
    if (raw == null) {
      return DriverStatus.active;
    }
    return parseApiEnum(
      values,
      (status) => status.apiValue,
      raw,
      'driver status',
    );
  }

  /// For URL query parameters: unknown text is `null`.
  static DriverStatus? tryParse(String? raw) => tryParseApiEnum(
    values,
    (status) => status.apiValue,
    raw,
    ignoreCase: true,
  );
}

/// `currentVehicle` inside a DriverResponse: `{id, vehicleNumber}`.
class VehicleSummary {
  const VehicleSummary({required this.id, required this.vehicleNumber});

  static VehicleSummary? fromJsonOrNull(Object? raw) {
    if (raw is! Map<String, dynamic> || raw['id'] is! num) {
      return null;
    }
    return VehicleSummary(
      id: (raw['id'] as num).toInt(),
      vehicleNumber: raw['vehicleNumber'] as String? ?? '',
    );
  }

  final int id;
  final String vehicleNumber;
}

/// `DriverResponse` (FR-DR01, FR-X01, FR-X02).
class Driver {
  const Driver({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.licenseNumber,
    required this.licenseExpiry,
    required this.licenseStatus,
    required this.status,
    this.daysUntilLicenseExpiry,
    this.currentVehicle,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.version = 0,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    final licenseExpiry = JsonReaders.date(json['licenseExpiry']);
    if (licenseExpiry == null) {
      throw const FormatException('Driver needs a licenseExpiry.');
    }
    return Driver(
      id: JsonReaders.requireInt(json, 'id'),
      fullName: JsonReaders.requireString(json, 'fullName'),
      phone: json['phone'] as String? ?? '',
      licenseNumber: json['licenseNumber'] as String? ?? '',
      licenseExpiry: licenseExpiry,
      licenseStatus: ExpiryStatus.fromApi(
        json['licenseStatus'],
        expiryDate: licenseExpiry,
      ),
      daysUntilLicenseExpiry: JsonReaders.intOrNull(
        json['daysUntilLicenseExpiry'],
      ),
      status: DriverStatus.fromApi(json['status']),
      currentVehicle: VehicleSummary.fromJsonOrNull(json['currentVehicle']),
      createdAt: JsonReaders.timestamp(json['createdAt']),
      updatedAt: JsonReaders.timestamp(json['updatedAt']),
      createdBy: json['createdBy'] as String?,
      version: JsonReaders.intOr(json['version'], 0),
    );
  }

  final int id;
  final String fullName;
  final String phone;
  final String licenseNumber;
  final DateTime licenseExpiry;
  final ExpiryStatus licenseStatus;
  final int? daysUntilLicenseExpiry;
  final DriverStatus status;
  final VehicleSummary? currentVehicle;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  /// v2.1 optimistic locking (ADR 0023): sent back in `PUT /drivers/{id}`.
  final int version;

  bool get isActive => status == DriverStatus.active;

  /// Saving this driver as [next] unassigns the current vehicle: an ACTIVE
  /// driver who becomes INACTIVE loses it on the server.
  bool losesVehicleOn(DriverStatus next) =>
      isActive && next == DriverStatus.inactive && currentVehicle != null;
}

/// `DriverRequest`; `UpdateDriverRequest` is the same plus `version`
/// ([toUpdateJson], contract 7.2.2).
class DriverInput {
  const DriverInput({
    required this.fullName,
    required this.phone,
    required this.licenseNumber,
    required this.licenseExpiry,
    this.status = DriverStatus.active,
  });

  /// Field names the server may report in `errors[].field`.
  static const Set<String> fieldNames = {
    'fullName',
    'phone',
    'licenseNumber',
    'licenseExpiry',
    'status',
  };

  final String fullName;
  final String phone;
  final String licenseNumber;
  final DateTime licenseExpiry;
  final DriverStatus status;

  /// Sends the phone already normalized (the server normalizes again).
  Map<String, dynamic> toJson() => {
    'fullName': fullName.trim(),
    'phone': DriverValidators.normalizePhone(phone),
    'licenseNumber': licenseNumber.trim(),
    'licenseExpiry': Formatters.isoDate(licenseExpiry),
    'status': status.apiValue,
  };

  /// `PUT /drivers/{id}` body: [toJson] plus the loaded [version].
  Map<String, dynamic> toUpdateJson(int version) => {
    ...toJson(),
    'version': version,
  };
}
