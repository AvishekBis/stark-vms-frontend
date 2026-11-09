import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/network/api_client.dart';
import 'package:stark_vms_frontend/features/documents/data/document_repository.dart';
import 'package:stark_vms_frontend/features/documents/data/vehicle_document.dart';
import 'package:stark_vms_frontend/features/documents/presentation/document_providers.dart';
import 'package:stark_vms_frontend/shared/models/expiry_status.dart';

import '../helpers/fakes_v2.dart';

void main() {
  Map<String, dynamic> documentJson() => {
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
    'createdAt': '2026-11-06T09:15:00Z',
    'createdBy': 'staff@stark.local',
  };

  group('VehicleDocument.fromJson', () {
    test('parses a DocumentResponse', () {
      final document = VehicleDocument.fromJson(documentJson());

      expect(document.id, 31);
      expect(document.vehicleId, 12);
      expect(document.documentType, DocumentType.taxToken);
      expect(document.documentType.label, 'Tax token');
      expect(document.issueDate, DateTime(2025, 12, 1));
      expect(document.expiryDate, DateTime(2026, 11, 30));
      expect(document.expiryStatus, ExpiryStatus.expiringSoon);
      expect(document.daysUntilExpiry, 12);
      expect(document.fileSize, 182344);
      expect(document.downloadName, 'tax-token.pdf');
    });

    test('optional fields may be null; unknown type becomes Other', () {
      final document = VehicleDocument.fromJson({
        ...documentJson(),
        'documentType': 'SOMETHING_NEW',
        'documentNumber': null,
        'issueDate': null,
        'fileName': null,
      });

      expect(document.documentType, DocumentType.other);
      expect(document.documentNumber, isNull);
      expect(document.issueDate, isNull);
      expect(document.downloadName, 'other-31');
    });

    test('expiry date is required', () {
      expect(
        () => VehicleDocument.fromJson({...documentJson(), 'expiryDate': null}),
        throwsFormatException,
      );
    });
  });

  group('DocumentUploadRules (BR-07, client side)', () {
    PickedFile file(String name, int size) =>
        PickedFile(name: name, size: size);

    test('PDF, JPG, JPEG and PNG up to 5 MB are accepted', () {
      expect(DocumentUploadRules.fileError(file('a.pdf', 1000)), isNull);
      expect(DocumentUploadRules.fileError(file('b.JPG', 1000)), isNull);
      expect(DocumentUploadRules.fileError(file('c.jpeg', 1000)), isNull);
      expect(
        DocumentUploadRules.fileError(file('d.png', 5 * 1024 * 1024)),
        isNull,
      );
    });

    test('larger than 5 MB is rejected', () {
      expect(
        DocumentUploadRules.fileError(file('big.pdf', 5 * 1024 * 1024 + 1)),
        'The file is larger than 5 MB.',
      );
    });

    test('other extensions are rejected', () {
      expect(
        DocumentUploadRules.fileError(file('notes.docx', 1000)),
        'Only PDF, JPG or PNG files are allowed.',
      );
      expect(
        DocumentUploadRules.fileError(file('noextension', 1000)),
        'Only PDF, JPG or PNG files are allowed.',
      );
    });

    test('no file and an empty file are rejected', () {
      expect(DocumentUploadRules.fileError(null), isNotNull);
      expect(
        DocumentUploadRules.fileError(file('a.pdf', 0)),
        'The file is empty.',
      );
    });

    test('expiry before issue is rejected, same day is fine', () {
      expect(
        DocumentUploadRules.expiryError(
          issueDate: DateTime(2026, 5, 2),
          expiryDate: DateTime(2026, 5, 1),
        ),
        'Expiry date must be on or after the issue date.',
      );
      expect(
        DocumentUploadRules.expiryError(
          issueDate: DateTime(2026, 5, 1),
          expiryDate: DateTime(2026, 5, 1),
        ),
        isNull,
      );
      expect(
        DocumentUploadRules.expiryError(expiryDate: DateTime(2026, 5, 1)),
        isNull,
      );
      expect(
        DocumentUploadRules.expiryError(issueDate: DateTime(2026, 5, 1)),
        'Expiry date is required.',
      );
    });

    test('declared content type follows the extension', () {
      expect(DocumentUploadRules.contentTypeFor('pdf'), 'application/pdf');
      expect(DocumentUploadRules.contentTypeFor('JPG'), 'image/jpeg');
      expect(DocumentUploadRules.contentTypeFor('png'), 'image/png');
    });
  });

  test('multipart body has the contract parts', () {
    final form = ApiDocumentRepository.buildFormData(
      DocumentUpload(
        documentType: DocumentType.insurance,
        documentNumber: '  INS-1 ',
        issueDate: DateTime(2026, 1, 1),
        expiryDate: DateTime(2026, 12, 31),
        file: PickedFile(
          name: 'policy.pdf',
          size: 4,
          bytes: Uint8List.fromList(const [0x25, 0x50, 0x44, 0x46]),
        ),
      ),
    );

    final fields = Map.fromEntries(form.fields);
    expect(fields, {
      'documentType': 'INSURANCE',
      'documentNumber': 'INS-1',
      'issueDate': '2026-01-01',
      'expiryDate': '2026-12-31',
    });
    expect(form.files.single.key, 'file');
    final MultipartFile part = form.files.single.value;
    expect(part.filename, 'policy.pdf');
    expect(part.contentType.toString(), 'application/pdf');
    expect(part.length, 4);
  });

  test('file name from Content-Disposition', () {
    expect(
      BinaryResponse.fileNameFromDisposition(
        'inline; filename="tax-token.pdf"',
      ),
      'tax-token.pdf',
    );
    expect(
      BinaryResponse.fileNameFromDisposition('attachment; filename=a.png'),
      'a.png',
    );
    expect(BinaryResponse.fileNameFromDisposition(null), isNull);
  });

  test('a 403 shows the delete message only for a delete', () {
    final forbidden = problem(403, type: 'forbidden', detail: 'Access denied.');

    expect(
      DocumentActions.errorMessage(
        forbidden,
        fallback: 'Could not delete.',
        forbidden: DocumentActions.deleteForbiddenMessage,
      ),
      'Only an administrator can delete documents.',
    );
    expect(
      DocumentActions.errorMessage(forbidden, fallback: 'Could not open.'),
      'Access denied.',
    );
    expect(
      DocumentActions.errorMessage(
        StateError('x'),
        fallback: 'Could not open.',
      ),
      'Could not open.',
    );
  });
}
