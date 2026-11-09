/// API enums from the contract, each with a display label.
library;

T _parseEnum<T extends Enum>(
  List<T> values,
  String Function(T) apiValue,
  Object? raw,
  String name,
) {
  for (final value in values) {
    if (apiValue(value) == raw) {
      return value;
    }
  }
  throw FormatException('Unknown $name: $raw');
}

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
      _parseEnum(values, (type) => type.apiValue, raw, 'vehicle type');
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
      : _parseEnum(values, (fuel) => fuel.apiValue, raw, 'fuel type');
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
      _parseEnum(values, (status) => status.apiValue, raw, 'vehicle status');
}
