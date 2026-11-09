import 'dart:typed_data';

import '../../../core/utils/dates.dart';
import '../../../core/utils/enum_parsing.dart';
import '../../../core/utils/json_readers.dart';
import '../../../shared/models/expiry_status.dart';

/// `DocumentType` (FR-D01).
enum DocumentType {
  registration('REGISTRATION', 'Registration'),
  taxToken('TAX_TOKEN', 'Tax token'),
  insurance('INSURANCE', 'Insurance'),
  fitnessCertificate('FITNESS_CERTIFICATE', 'Fitness certificate'),
  routePermit('ROUTE_PERMIT', 'Route permit'),
  other('OTHER', 'Other');

  const DocumentType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// Unknown types are shown as "Other" rather than failing the whole list.
  static DocumentType fromApi(Object? raw) =>
      tryParseApiEnum(values, (type) => type.apiValue, raw) ??
      DocumentType.other;
}

/// `DocumentResponse` (FR-D01, FR-D02).
class VehicleDocument {
  const VehicleDocument({
    required this.id,
    required this.vehicleId,
    required this.vehicleNumber,
    required this.documentType,
    required this.expiryDate,
    required this.expiryStatus,
    this.documentNumber,
    this.issueDate,
    this.daysUntilExpiry,
    this.fileName,
    this.contentType,
    this.fileSize,
    this.createdAt,
    this.createdBy,
  });

  factory VehicleDocument.fromJson(Map<String, dynamic> json) {
    final expiryDate = JsonReaders.date(json['expiryDate']);
    if (expiryDate == null) {
      throw const FormatException('Document needs an expiryDate.');
    }
    return VehicleDocument(
      id: JsonReaders.requireInt(json, 'id'),
      vehicleId: JsonReaders.requireInt(json, 'vehicleId'),
      vehicleNumber: json['vehicleNumber'] as String? ?? '',
      documentType: DocumentType.fromApi(json['documentType']),
      documentNumber: json['documentNumber'] as String?,
      issueDate: JsonReaders.date(json['issueDate']),
      expiryDate: expiryDate,
      expiryStatus: ExpiryStatus.fromApi(
        json['expiryStatus'],
        expiryDate: expiryDate,
      ),
      daysUntilExpiry: JsonReaders.intOrNull(json['daysUntilExpiry']),
      fileName: json['fileName'] as String?,
      contentType: json['contentType'] as String?,
      fileSize: JsonReaders.intOrNull(json['fileSize']),
      createdAt: JsonReaders.timestamp(json['createdAt']),
      createdBy: json['createdBy'] as String?,
    );
  }

  final int id;
  final int vehicleId;
  final String vehicleNumber;
  final DocumentType documentType;
  final String? documentNumber;
  final DateTime? issueDate;
  final DateTime expiryDate;
  final ExpiryStatus expiryStatus;
  final int? daysUntilExpiry;
  final String? fileName;
  final String? contentType;
  final int? fileSize;
  final DateTime? createdAt;
  final String? createdBy;

  /// Name used when the file is saved.
  String get downloadName {
    final name = fileName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return '${documentType.apiValue.toLowerCase()}-$id';
  }
}

/// A file chosen in the browser. [bytes] is `null` when the file was not
/// read because it is already too large to upload.
class PickedFile {
  const PickedFile({required this.name, required this.size, this.bytes});

  final String name;
  final int size;
  final Uint8List? bytes;

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }
}

/// Client-side copy of the upload rules (BR-07); the server checks again,
/// including the file's magic bytes.
abstract final class DocumentUploadRules {
  static const int maxFileBytes = 5 * 1024 * 1024;
  static const int documentNumberMaxLength = 60;
  static const List<String> allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

  static const String fileRequiredMessage = 'Choose a PDF, JPG or PNG file.';
  static const String fileEmptyMessage = 'The file is empty.';
  static const String fileTypeMessage =
      'Only PDF, JPG or PNG files are allowed.';
  static const String fileTooLargeMessage = 'The file is larger than 5 MB.';
  static const String expiryRequiredMessage = 'Expiry date is required.';
  static const String expiryBeforeIssueMessage =
      'Expiry date must be on or after the issue date.';

  static String? fileError(PickedFile? file) {
    if (file == null) {
      return fileRequiredMessage;
    }
    if (!allowedExtensions.contains(file.extension)) {
      return fileTypeMessage;
    }
    if (file.size <= 0) {
      return fileEmptyMessage;
    }
    if (file.size > maxFileBytes) {
      return fileTooLargeMessage;
    }
    return null;
  }

  static String? expiryError({DateTime? issueDate, DateTime? expiryDate}) {
    if (expiryDate == null) {
      return expiryRequiredMessage;
    }
    if (issueDate != null && Dates.daysBetween(issueDate, expiryDate) < 0) {
      return expiryBeforeIssueMessage;
    }
    return null;
  }

  static String? documentNumberError(String? value) {
    if (value != null && value.trim().length > documentNumberMaxLength) {
      return 'Document number must be at most $documentNumberMaxLength characters.';
    }
    return null;
  }

  /// The declared content type; it must agree with the extension (BR-07).
  static String contentTypeFor(String extension) {
    return switch (extension.toLowerCase()) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => 'application/octet-stream',
    };
  }
}

/// The multipart upload request (contract 6.5).
class DocumentUpload {
  const DocumentUpload({
    required this.documentType,
    required this.expiryDate,
    required this.file,
    this.documentNumber,
    this.issueDate,
  });

  /// Field names the server may report in `errors[].field`.
  static const Set<String> fieldNames = {
    'file',
    'documentType',
    'documentNumber',
    'issueDate',
    'expiryDate',
  };

  final DocumentType documentType;
  final String? documentNumber;
  final DateTime? issueDate;
  final DateTime expiryDate;
  final PickedFile file;
}
