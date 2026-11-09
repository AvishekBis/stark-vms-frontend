import '../../../core/network/page_response.dart';
import '../../../core/utils/enum_parsing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json_readers.dart';

/// `MaintenanceType` (FR-M01).
enum MaintenanceType {
  routineService('ROUTINE_SERVICE', 'Routine service'),
  oilChange('OIL_CHANGE', 'Oil change'),
  tyre('TYRE', 'Tyre'),
  brake('BRAKE', 'Brake'),
  engine('ENGINE', 'Engine'),
  electrical('ELECTRICAL', 'Electrical'),
  bodyWork('BODY_WORK', 'Body work'),
  inspection('INSPECTION', 'Inspection'),
  repair('REPAIR', 'Repair'),
  other('OTHER', 'Other');

  const MaintenanceType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// Unknown types are shown as "Other" rather than failing the history.
  static MaintenanceType fromApi(Object? raw) =>
      tryParseApiEnum(values, (type) => type.apiValue, raw) ??
      MaintenanceType.other;
}

/// `MaintenanceResponse` (FR-M01, FR-X01). `cost` is in BDT.
class MaintenanceRecord {
  const MaintenanceRecord({
    required this.id,
    required this.vehicleId,
    required this.serviceDate,
    required this.maintenanceType,
    required this.cost,
    this.vehicleNumber,
    this.vendorName,
    this.odometerKm,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.version = 0,
  });

  factory MaintenanceRecord.fromJson(Map<String, dynamic> json) {
    final serviceDate = JsonReaders.date(json['serviceDate']);
    if (serviceDate == null) {
      throw const FormatException('Maintenance record needs a serviceDate.');
    }
    return MaintenanceRecord(
      id: JsonReaders.requireInt(json, 'id'),
      vehicleId: JsonReaders.requireInt(json, 'vehicleId'),
      vehicleNumber: json['vehicleNumber'] as String?,
      serviceDate: serviceDate,
      maintenanceType: MaintenanceType.fromApi(json['maintenanceType']),
      cost: JsonReaders.doubleOr(json['cost'], 0),
      vendorName: json['vendorName'] as String?,
      odometerKm: JsonReaders.intOrNull(json['odometerKm']),
      notes: json['notes'] as String?,
      createdAt: JsonReaders.timestamp(json['createdAt']),
      updatedAt: JsonReaders.timestamp(json['updatedAt']),
      createdBy: json['createdBy'] as String?,
      version: JsonReaders.intOr(json['version'], 0),
    );
  }

  final int id;
  final int vehicleId;
  final String? vehicleNumber;
  final DateTime serviceDate;
  final MaintenanceType maintenanceType;
  final double cost;
  final String? vendorName;
  final int? odometerKm;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  /// v2.1 optimistic locking (ADR 0023): sent back in
  /// `PUT /maintenance/{recordId}`.
  final int version;
}

/// `MaintenanceRequest`; `UpdateMaintenanceRequest` is the same plus
/// `version` ([toUpdateJson], contract 7.2.2).
class MaintenanceInput {
  const MaintenanceInput({
    required this.serviceDate,
    required this.maintenanceType,
    required this.cost,
    this.vendorName,
    this.odometerKm,
    this.notes,
  });

  static const Set<String> fieldNames = {
    'serviceDate',
    'maintenanceType',
    'cost',
    'vendorName',
    'odometerKm',
    'notes',
  };

  final DateTime serviceDate;
  final MaintenanceType maintenanceType;
  final double cost;
  final String? vendorName;
  final int? odometerKm;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'serviceDate': Formatters.isoDate(serviceDate),
    'maintenanceType': maintenanceType.apiValue,
    'cost': cost,
    'vendorName': _blankToNull(vendorName),
    'odometerKm': odometerKm,
    'notes': _blankToNull(notes),
  };

  /// `PUT /maintenance/{recordId}` body: [toJson] plus the loaded [version].
  Map<String, dynamic> toUpdateJson(int version) => {
    ...toJson(),
    'version': version,
  };

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

/// `MaintenanceHistoryResponse` (FR-M02): one page of records plus the
/// total cost over **all** records of the vehicle.
class MaintenanceHistory {
  const MaintenanceHistory({
    required this.page,
    required this.totalCost,
    required this.recordCount,
  });

  factory MaintenanceHistory.fromJson(Map<String, dynamic> json) {
    final page = PageResponse.fromJson(json, MaintenanceRecord.fromJson);
    return MaintenanceHistory(
      page: page,
      totalCost: JsonReaders.doubleOr(json['totalCost'], 0),
      recordCount: JsonReaders.intOr(json['recordCount'], page.totalElements),
    );
  }

  final PageResponse<MaintenanceRecord> page;
  final double totalCost;
  final int recordCount;

  List<MaintenanceRecord> get records => page.content;
}
