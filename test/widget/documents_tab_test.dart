import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/platform/file_opener.dart';
import 'package:stark_vms_frontend/features/auth/data/auth_models.dart';
import 'package:stark_vms_frontend/features/auth/presentation/auth_controller.dart';
import 'package:stark_vms_frontend/features/documents/data/document_file_picker.dart';
import 'package:stark_vms_frontend/features/documents/data/document_repository.dart';
import 'package:stark_vms_frontend/features/documents/data/vehicle_document.dart';
import 'package:stark_vms_frontend/features/documents/presentation/documents_tab.dart';
import 'package:stark_vms_frontend/shared/models/expiry_status.dart';

import '../helpers/fakes.dart';
import '../helpers/fakes_v2.dart';
import '../helpers/pump_app.dart';

void main() {
  late FakeDocumentRepository repository;
  late FakeFileOpener opener;
  late FakeDocumentFilePicker picker;

  Future<void> pumpTab(
    WidgetTester tester, {
    required User user,
    // The test font is wider than real fonts, so the full table needs room.
    Size size = const Size(1800, 1000),
  }) async {
    opener = FakeFileOpener();
    await pumpScreen(
      tester,
      const Scaffold(
        body: DocumentsTab(vehicleId: 12, vehicleNumber: 'DHK-1234'),
      ),
      size: size,
      overrides: [
        documentRepositoryProvider.overrideWithValue(repository),
        fileOpenerProvider.overrideWithValue(opener),
        documentFilePickerProvider.overrideWithValue(picker),
        authControllerProvider.overrideWith(
          () => FakeAuthController(AuthState.signedIn(sessionFor(user))),
        ),
      ],
    );
  }

  setUp(() {
    repository = FakeDocumentRepository(
      seed: [
        testDocument(
          id: 2,
          type: DocumentType.insurance,
          status: ExpiryStatus.valid,
          daysUntilExpiry: 200,
          expiryDate: DateTime(2027, 6, 1),
        ),
        testDocument(
          id: 1,
          status: ExpiryStatus.expired,
          daysUntilExpiry: -3,
          expiryDate: DateTime(2026, 11, 15),
        ),
      ],
    );
    picker = FakeDocumentFilePicker(null);
  });

  testWidgets('lists documents soonest expiry first with badges (FR-D02)', (
    tester,
  ) async {
    await pumpTab(tester, user: staffUser);

    expect(find.text('2 documents'), findsOneWidget);
    expect(find.text('Expired 3 days ago'), findsOneWidget);
    expect(find.text('Valid'), findsOneWidget);
    final expiredRow = tester.getTopLeft(find.text('Expired 3 days ago'));
    final validRow = tester.getTopLeft(find.text('Valid'));
    expect(expiredRow.dy, lessThan(validRow.dy));
    // FR-X01: upload date and uploader in the full table.
    expect(find.textContaining('staff@stark.local'), findsNWidgets(2));
  });

  testWidgets('STAFF can view and download but not delete', (tester) async {
    await pumpTab(tester, user: staffUser);

    expect(find.byKey(const ValueKey('document.view.1')), findsOneWidget);
    expect(find.byKey(const ValueKey('document.download.1')), findsOneWidget);
    expect(find.byKey(const ValueKey('document.delete.1')), findsNothing);
    expect(find.byKey(const ValueKey('document.delete.2')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('document.view.1')));
    await tester.pumpAndSettle();
    expect(opener.opened, ['tax-token.pdf']);
  });

  testWidgets('ADMIN delete asks for confirmation', (tester) async {
    await pumpTab(tester, user: adminUser);

    await tester.tap(find.byKey(const ValueKey('document.delete.1')));
    await tester.pumpAndSettle();
    expect(find.text('Delete document?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm.ok')));
    await tester.pumpAndSettle();

    expect(repository.deleted, [1]);
    expect(find.text('1 document'), findsOneWidget);
  });

  testWidgets('upload dialog checks the file before sending (BR-07)', (
    tester,
  ) async {
    picker.file = const PickedFile(name: 'scan.docx', size: 1000);
    await pumpTab(tester, user: staffUser);

    await tester.tap(find.byKey(const Key('documents.upload')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('uploadDialog.pickFile')));
    await tester.pumpAndSettle();
    expect(
      find.text('Only PDF, JPG or PNG files are allowed.'),
      findsOneWidget,
    );

    picker.file = const PickedFile(name: 'big.pdf', size: 6 * 1024 * 1024);
    await tester.tap(find.byKey(const Key('uploadDialog.pickFile')));
    await tester.pumpAndSettle();
    expect(find.text('The file is larger than 5 MB.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('uploadDialog.submit')));
    await tester.pumpAndSettle();
    expect(find.text('Document type is required.'), findsOneWidget);
    expect(find.text('Expiry date is required.'), findsOneWidget);
    expect(repository.uploads, isEmpty);
  });

  testWidgets('a 413 from the server is shown under the file', (tester) async {
    picker.file = PickedFile(
      name: 'scan.pdf',
      size: 4,
      bytes: Uint8List.fromList(const [0x25, 0x50, 0x44, 0x46]),
    );
    repository.uploadError = problem(
      413,
      type: 'file-too-large',
      title: 'File too large',
      detail: 'The file is larger than 5 MB.',
    );
    await pumpTab(tester, user: staffUser);

    await tester.tap(find.byKey(const Key('documents.upload')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('uploadDialog.type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tax token').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('uploadDialog.expiryDate')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('uploadDialog.pickFile')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('uploadDialog.submit')));
    await tester.pumpAndSettle();

    expect(repository.uploads, hasLength(1));
    expect(repository.uploads.single.documentType, DocumentType.taxToken);
    expect(find.text('The file is larger than 5 MB.'), findsOneWidget);
    expect(find.byKey(const Key('uploadDialog')), findsOneWidget);
  });

  testWidgets('shows cards on phones', (tester) async {
    await pumpTab(tester, user: staffUser, size: const Size(400, 900));

    expect(find.byKey(const ValueKey('document.card.1')), findsOneWidget);
    expect(find.byKey(const Key('documents.table')), findsNothing);
  });

  testWidgets('empty state when the vehicle has no documents', (tester) async {
    repository = FakeDocumentRepository();
    await pumpTab(tester, user: staffUser);

    expect(find.text('No documents yet'), findsOneWidget);
  });
}
