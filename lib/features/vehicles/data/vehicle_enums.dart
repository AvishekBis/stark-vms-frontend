/// API enums from the contract, each with a display label.
library;

import '../../../core/utils/enum_parsing.dart';

enum VehicleType {
  car('CAR', 'Car'),
  suv('SUV', 'SUV'),
  microbus('MICROBUS', 'Microbus'),
  bus('BUS', 'Bus'),
  truck('TRUCK', 'Truck'),
  pickup('PICKUP', 'Pickup'),
  motorcycle('MOTORCYCLE', 'Motorcycle'),
  other('OTHER', 'Other');

  const VehicleType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static VehicleType fromApi(Object? raw) =>
      parseApiEnum(values, (type) => type.apiValue, raw, 'vehicle type');

  /// For URL query parameters: unknown text is `null` (no filter).
  static VehicleType? tryParse(String? raw) =>
      tryParseApiEnum(values, (type) => type.apiValue, raw, ignoreCase: true);
}

enum FuelType {
  petrol('PETROL', 'Petrol'),
  octane('OCTANE', 'Octane'),
  diesel('DIESEL', 'Diesel'),
  cng('CNG', 'CNG'),
  lpg('LPG', 'LPG'),
  hybrid('HYBRID', 'Hybrid'),
  electric('ELECTRIC', 'Electric');

  const FuelType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// `null` stays `null`: fuel type is optional.
  static FuelType? fromApiOrNull(Object? raw) => raw == null
      ? null
      : parseApiEnum(values, (fuel) => fuel.apiValue, raw, 'fuel type');
}

/// BR-04: only these three statuses exist.
enum VehicleStatus {
  active('ACTIVE', 'Active'),
  inactive('INACTIVE', 'Inactive'),
  maintenance('MAINTENANCE', 'Maintenance');

  const VehicleStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static VehicleStatus fromApi(Object? raw) =>
      parseApiEnum(values, (status) => status.apiValue, raw, 'vehicle status');

  /// For URL query parameters: unknown text is `null` (no filter).
  static VehicleStatus? tryParse(String? raw) => tryParseApiEnum(
    values,
    (status) => status.apiValue,
    raw,
    ignoreCase: true,
  );
}
