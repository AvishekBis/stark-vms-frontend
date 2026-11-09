import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/network/page_response.dart';
import '../../../core/network/response_parsing.dart';
import '../../../core/utils/formatters.dart';
import 'vehicle_document.dart';

/// Vehicle document endpoints (FR-D01, FR-D02).
abstract interface class DocumentRepository {
  /// All documents of a vehicle (not paged), soonest expiry first.
  Future<List<VehicleDocument>> listForVehicle(int vehicleId);

  /// Multipart upload. 400 with `errors[]` for bad data, 413 for > 5 MB.
  Future<VehicleDocument> upload(int vehicleId, DocumentUpload upload);

  Future<VehicleDocument> get(int documentId);

  /// The stored bytes (needs the bearer token, so no plain link).
  Future<BinaryResponse> fetchFile(int documentId, {bool download = false});

  /// ADMIN only.
  Future<void> delete(int documentId);

  /// Expired and expiring documents (`expiryDate <= today + withinDays`).
  Future<PageResponse<VehicleDocument>> expiring({
    int withinDays = defaultWithinDays,
    int page = 0,
    int size = defaultPageSize,
  });

  static const int defaultWithinDays = 30;
  static const int defaultPageSize = 20;
}

class ApiDocumentRepository implements DocumentRepository {
  const ApiDocumentRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<VehicleDocument>> listForVehicle(int vehicleId) async {
    final body = await _client.get('/vehicles/$vehicleId/documents');
    return ResponseParsing.parse(
      () =>
          ResponseParsing.objectList(body)
              .map(VehicleDocument.fromJson)
              .toList(growable: false),
    );
  }

  @override
  Future<VehicleDocument> upload(int vehicleId, DocumentUpload upload) async {
    final body = await _client.postMultipart(
      '/vehicles/$vehicleId/documents',
      buildFormData(upload),
    );
    return _document(body);
  }

  /// Parts: `file`, `documentType`, `documentNumber?`, `issueDate?`,
  /// `expiryDate` (contract 6.5).
  static FormData buildFormData(DocumentUpload upload) {
    final file = upload.file;
    final bytes = file.bytes;
    if (bytes == null) {
      throw ArgumentError('The picked file has not been read.');
    }
    final number = upload.documentNumber?.trim();
    final issueDate = upload.issueDate;
    return FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: file.name,
        contentType: DioMediaType.parse(
          DocumentUploadRules.contentTypeFor(file.extension),
        ),
      ),
      'documentType': upload.documentType.apiValue,
      if (number != null && number.isNotEmpty) 'documentNumber': number,
      if (issueDate != null) 'issueDate': Formatters.isoDate(issueDate),
      'expiryDate': Formatters.isoDate(upload.expiryDate),
    });
  }

  @override
  Future<VehicleDocument> get(int documentId) async =>
      _document(await _client.get('/documents/$documentId'));

  @override
  Future<BinaryResponse> fetchFile(int documentId, {bool download = false}) {
    return _client.getBytes(
      '/documents/$documentId/file',
      queryParameters: {'download': download},
    );
  }

  @override
  Future<void> delete(int documentId) =>
      _client.delete('/documents/$documentId');

  @override
  Future<PageResponse<VehicleDocument>> expiring({
    int withinDays = DocumentRepository.defaultWithinDays,
    int page = 0,
    int size = DocumentRepository.defaultPageSize,
  }) async {
    final body = await _client.get(
      '/documents/expiring',
      queryParameters: {'withinDays': withinDays, 'page': page, 'size': size},
    );
    return ResponseParsing.parse(
      () => PageResponse.fromJson(
        ResponseParsing.object(body),
        VehicleDocument.fromJson,
      ),
    );
  }

  static VehicleDocument _document(Object? body) => ResponseParsing.parse(
    () => VehicleDocument.fromJson(ResponseParsing.object(body)),
  );
}

final documentRepositoryProvider = Provider<DocumentRepository>(
  (ref) => ApiDocumentRepository(ref.watch(apiClientProvider)),
);
