import 'dart:typed_data';

import 'package:stark_vms_frontend/core/network/api_client.dart';
import 'package:stark_vms_frontend/core/network/api_exception.dart';
import 'package:stark_vms_frontend/core/network/page_response.dart';
import 'package:stark_vms_frontend/core/platform/file_opener.dart';
import 'package:stark_vms_frontend/features/assignments/data/assignment.dart';
import 'package:stark_vms_frontend/features/assignments/data/assignment_repository.dart';
import 'package:stark_vms_frontend/features/dashboard/data/dashboard_repository.dart';
import 'package:stark_vms_frontend/features/dashboard/data/dashboard_summary.dart';
import 'package:stark_vms_frontend/features/documents/data/document_file_picker.dart';
import 'package:stark_vms_frontend/features/documents/data/document_repository.dart';
import 'package:stark_vms_frontend/features/documents/data/vehicle_document.dart';
import 'package:stark_vms_frontend/features/drivers/data/driver.dart';
import 'package:stark_vms_frontend/features/drivers/data/driver_query.dart';
import 'package:stark_vms_frontend/features/drivers/data/driver_repository.dart';
import 'package:stark_vms_frontend/features/maintenance/data/maintenance_record.dart';
import 'package:stark_vms_frontend/features/maintenance/data/maintenance_repository.dart';
import 'package:stark_vms_frontend/shared/models/expiry_status.dart';

/// Test-only v2.0 data and fakes (drivers, assignments, documents,
/// maintenance, dashboard). Production code never contains fleet data.

/// A Problem Details error as the server would send it.
ApiException problem(
  int status, {
  required String type,
  required String detail,
  String? title,
  List<Map<String, String>>? errors,
}) {
  return ApiException.fromProblemDetails({
    'type': 'https://stark-vms/errors/$type',
    'title': ?title,
    'status': status,
    'detail': detail,
    'errors': ?errors,
  });
}

PageResponse<T> pageOf<T>(List<T> items, {int page = 0, int size = 20}) {
  final content = items.skip(page * size).take(size).toList();
  return PageResponse(
    content: content,
    page: page,
    size: size,
    totalElements: items.length,
    totalPages: (items.length / size).ceil(),
  );
}

Driver testDriver({
  int id = 4,
  String fullName = 'Rahim Uddin',
  String phone = '01711000001',
  DriverStatus status = DriverStatus.active,
  ExpiryStatus licenseStatus = ExpiryStatus.valid,
  int daysUntilLicenseExpiry = 147,
  VehicleSummary? currentVehicle,
  int version = 0,
}) {
  return Driver(
    id: id,
    fullName: fullName,
    phone: phone,
    licenseNumber: 'DK0123456L0000$id',
    licenseExpiry: DateTime(2027, 3, 31),
    licenseStatus: licenseStatus,
    daysUntilLicenseExpiry: daysUntilLicenseExpiry,
    status: status,
    currentVehicle: currentVehicle,
    createdAt: DateTime.utc(2026, 11, 6, 9, 15),
    updatedAt: DateTime.utc(2026, 11, 6, 9, 15),
    createdBy: 'admin@stark.local',
    version: version,
  );
}

class FakeDriverRepository implements DriverRepository {
  FakeDriverRepository({List<Driver> seed = const [], this.saveError})
    : drivers = [...seed];

  final List<Driver> drivers;
  ApiException? saveError;
  final List<DriverQuery> listQueries = [];
  final List<DriverInput> saved = [];

  /// The `version` sent with every update (contract 7.2.2).
  final List<int> updateVersions = [];

  @override
  Future<PageResponse<Driver>> list(DriverQuery query) async {
    listQueries.add(query);
    final matches = drivers
        .where(
          (d) => d.fullName.toLowerCase().contains(query.search.toLowerCase()),
        )
        .where((d) => query.status == null || d.status == query.status)
        .where((d) => query.available != true || d.currentVehicle == null)
        .toList();
    return pageOf(matches, page: query.page, size: query.size);
  }

  @override
  Future<Driver> get(int id) async => drivers.firstWhere(
    (d) => d.id == id,
    orElse: () => throw ApiException.fromProblemDetails({'status': 404}),
  );

  @override
  Future<Driver> create(DriverInput input) async {
    saved.add(input);
    final error = saveError;
    if (error != null) {
      throw error;
    }
    final driver = testDriver(
      id: drivers.length + 10,
      fullName: input.fullName,
    );
    drivers.add(driver);
    return driver;
  }

  @override
  Future<Driver> update(
    int id,
    DriverInput input, {
    required int version,
  }) async {
    saved.add(input);
    updateVersions.add(version);
    final error = saveError;
    if (error != null) {
      throw error;
    }
    final driver = testDriver(
      id: id,
      fullName: input.fullName,
      status: input.status,
      version: version + 1,
    );
    drivers[drivers.indexWhere((d) => d.id == id)] = driver;
    return driver;
  }

  @override
  Future<void> delete(int id) async => drivers.removeWhere((d) => d.id == id);
}

Assignment testAssignment({
  int id = 9,
  int vehicleId = 12,
  int driverId = 4,
  bool current = true,
}) {
  return Assignment(
    id: id,
    vehicleId: vehicleId,
    vehicleNumber: 'DHK-1234',
    driverId: driverId,
    driverName: 'Rahim Uddin',
    current: current,
    assignedAt: DateTime.utc(2026, 11, 18, 4),
    unassignedAt: current ? null : DateTime.utc(2026, 11, 20, 4),
    assignedBy: 'admin@stark.local',
  );
}

class FakeAssignmentRepository implements AssignmentRepository {
  FakeAssignmentRepository({this.assignError, this.history = const []});

  ApiException? assignError;
  final List<Assignment> history;
  final List<(int, int)> assignCalls = [];
  final List<int> unassignCalls = [];

  @override
  Future<Assignment> assign({
    required int vehicleId,
    required int driverId,
  }) async {
    assignCalls.add((vehicleId, driverId));
    final error = assignError;
    if (error != null) {
      throw error;
    }
    return testAssignment(vehicleId: vehicleId, driverId: driverId);
  }

  @override
  Future<void> unassign(int vehicleId) async => unassignCalls.add(vehicleId);

  @override
  Future<PageResponse<Assignment>> vehicleHistory(
    int vehicleId, {
    int page = 0,
    int size = AssignmentRepository.defaultPageSize,
  }) async => pageOf(
    history.where((a) => a.vehicleId == vehicleId).toList(),
    page: page,
    size: size,
  );

  @override
  Future<PageResponse<Assignment>> driverHistory(
    int driverId, {
    int page = 0,
    int size = AssignmentRepository.defaultPageSize,
  }) async => pageOf(
    history.where((a) => a.driverId == driverId).toList(),
    page: page,
    size: size,
  );
}

VehicleDocument testDocument({
  int id = 31,
  int vehicleId = 12,
  DocumentType type = DocumentType.taxToken,
  ExpiryStatus status = ExpiryStatus.expiringSoon,
  int daysUntilExpiry = 12,
  DateTime? expiryDate,
}) {
  return VehicleDocument(
    id: id,
    vehicleId: vehicleId,
    vehicleNumber: 'DHK-1234',
    documentType: type,
    documentNumber: 'TT-2026-00$id',
    issueDate: DateTime(2025, 12, 1),
    expiryDate: expiryDate ?? DateTime(2026, 11, 30),
    expiryStatus: status,
    daysUntilExpiry: daysUntilExpiry,
    fileName: 'tax-token.pdf',
    contentType: 'application/pdf',
    fileSize: 182344,
    createdAt: DateTime.utc(2026, 11, 6, 9, 15),
    createdBy: 'staff@stark.local',
  );
}

class FakeDocumentRepository implements DocumentRepository {
  FakeDocumentRepository({
    List<VehicleDocument> seed = const [],
    this.uploadError,
  }) : documents = [...seed];

  final List<VehicleDocument> documents;
  ApiException? uploadError;
  final List<DocumentUpload> uploads = [];
  final List<int> deleted = [];
  final List<int> expiringWithinDays = [];

  @override
  Future<List<VehicleDocument>> listForVehicle(int vehicleId) async =>
      documents.where((d) => d.vehicleId == vehicleId).toList();

  @override
  Future<VehicleDocument> upload(int vehicleId, DocumentUpload upload) async {
    uploads.add(upload);
    final error = uploadError;
    if (error != null) {
      throw error;
    }
    final document = testDocument(
      id: 100 + uploads.length,
      vehicleId: vehicleId,
      type: upload.documentType,
      expiryDate: upload.expiryDate,
    );
    documents.add(document);
    return document;
  }

  @override
  Future<VehicleDocument> get(int documentId) async =>
      documents.firstWhere((d) => d.id == documentId);

  @override
  Future<BinaryResponse> fetchFile(
    int documentId, {
    bool download = false,
  }) async {
    return BinaryResponse(
      bytes: Uint8List.fromList(const [0x25, 0x50, 0x44, 0x46]),
      contentType: 'application/pdf',
    );
  }

  @override
  Future<void> delete(int documentId) async {
    deleted.add(documentId);
    documents.removeWhere((d) => d.id == documentId);
  }

  @override
  Future<PageResponse<VehicleDocument>> expiring({
    int withinDays = DocumentRepository.defaultWithinDays,
    int page = 0,
    int size = DocumentRepository.defaultPageSize,
  }) async {
    expiringWithinDays.add(withinDays);
    return pageOf(documents, page: page, size: size);
  }
}

/// Records what would have been opened in the browser.
class FakeFileOpener implements FileOpener {
  final List<String> opened = [];
  final List<String> downloaded = [];

  @override
  Future<void> open(
    FileLoader load, {
    required String fileName,
    String? contentType,
  }) async {
    await load();
    opened.add(fileName);
  }

  @override
  Future<void> download(
    FileLoader load, {
    required String fileName,
    String? contentType,
  }) async {
    await load();
    downloaded.add(fileName);
  }
}

/// Returns a prepared file instead of opening the browser dialog.
class FakeDocumentFilePicker implements DocumentFilePicker {
  FakeDocumentFilePicker(this.file);

  PickedFile? file;

  @override
  Future<PickedFile?> pick() async => file;
}

MaintenanceRecord testMaintenance({
  int id = 1,
  int vehicleId = 12,
  double cost = 3500,
  MaintenanceType type = MaintenanceType.oilChange,
  String? vendorName = 'Navana Service Centre',
  int version = 0,
}) {
  return MaintenanceRecord(
    id: id,
    vehicleId: vehicleId,
    vehicleNumber: 'DHK-1234',
    serviceDate: DateTime(2026, 11, 1),
    maintenanceType: type,
    cost: cost,
    vendorName: vendorName,
    odometerKm: 45210,
    notes: 'Synthetic oil',
    createdAt: DateTime.utc(2026, 11, 1, 8),
    createdBy: 'staff@stark.local',
    version: version,
  );
}

class FakeMaintenanceRepository implements MaintenanceRepository {
  FakeMaintenanceRepository({
    List<MaintenanceRecord> seed = const [],
    this.totalCost,
  }) : records = [...seed];

  final List<MaintenanceRecord> records;

  /// Overrides the computed sum (the server sums ALL records).
  final double? totalCost;
  final List<MaintenanceInput> saved = [];

  /// The `version` sent with every update (contract 7.2.2).
  final List<int> updateVersions = [];

  /// When set, updates fail with this error (e.g. 409 stale-version).
  ApiException? updateError;

  @override
  Future<MaintenanceHistory> history(
    int vehicleId, {
    int page = 0,
    int size = MaintenanceRepository.defaultPageSize,
  }) async {
    final mine = records.where((r) => r.vehicleId == vehicleId).toList();
    return MaintenanceHistory(
      page: pageOf(mine, page: page, size: size),
      totalCost: totalCost ?? mine.fold<double>(0, (sum, r) => sum + r.cost),
      recordCount: mine.length,
    );
  }

  @override
  Future<MaintenanceRecord> create(
    int vehicleId,
    MaintenanceInput input,
  ) async {
    saved.add(input);
    final record = testMaintenance(
      id: records.length + 1,
      vehicleId: vehicleId,
      cost: input.cost,
    );
    records.add(record);
    return record;
  }

  @override
  Future<MaintenanceRecord> get(int recordId) async =>
      records.firstWhere((r) => r.id == recordId);

  @override
  Future<MaintenanceRecord> update(
    int recordId,
    MaintenanceInput input, {
    required int version,
  }) async {
    saved.add(input);
    updateVersions.add(version);
    final error = updateError;
    if (error != null) {
      throw error;
    }
    return records.firstWhere((r) => r.id == recordId);
  }

  @override
  Future<void> delete(int recordId) async =>
      records.removeWhere((r) => r.id == recordId);
}

class FakeDashboardRepository implements DashboardRepository {
  FakeDashboardRepository({required this.summaryValue, this.failuresLeft = 0});

  final DashboardSummary summaryValue;

  /// The first [failuresLeft] calls fail (to test error + retry).
  int failuresLeft;
  int calls = 0;

  @override
  Future<DashboardSummary> summary() async {
    calls++;
    if (failuresLeft > 0) {
      failuresLeft--;
      throw const ApiException(
        kind: ApiErrorKind.network,
        message: 'Cannot reach the server.',
      );
    }
    return summaryValue;
  }
}

/// The contract 6.7 example, with one expiring document and licence.
Map<String, dynamic> dashboardJson() => {
  'vehicles': {'total': 26, 'active': 18, 'inactive': 3, 'maintenance': 5},
  'documents': {'expired': 2, 'expiringSoon': 4, 'withinDays': 30},
  'maintenance': {'month': '2026-11', 'count': 7, 'totalCost': 48250.0},
  'drivers': {
    'total': 12,
    'active': 11,
    'assigned': 9,
    'licensesExpired': 1,
    'licensesExpiringSoon': 2,
  },
  'expiringDocuments': [
    {
      'id': 31,
      'vehicleId': 12,
      'vehicleNumber': 'DHK-1234',
      'documentType': 'TAX_TOKEN',
      'documentNumber': 'TT-2026-0099',
      'issueDate': '2025-12-01',
      'expiryDate': '2026-11-30',
      'expiryStatus': 'EXPIRING_SOON',
      'daysUntilExpiry': 12,
      'fileName': 'tax-token.pdf',
      'contentType': 'application/pdf',
      'fileSize': 182344,
    },
  ],
  'expiringLicenses': [
    {
      'id': 4,
      'fullName': 'Rahim Uddin',
      'phone': '01711000001',
      'licenseNumber': 'DK0123456L00001',
      'licenseExpiry': '2026-11-02',
      'licenseStatus': 'EXPIRED',
      'daysUntilLicenseExpiry': -3,
      'status': 'ACTIVE',
      'currentVehicle': null,
    },
  ],
  'generatedAt': '2026-11-18T04:00:00Z',
};
