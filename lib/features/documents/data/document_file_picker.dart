import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'vehicle_document.dart';

/// Lets the user choose a PDF / JPG / PNG file (behind an interface so
/// widget tests can supply a file without a browser dialog).
abstract interface class DocumentFilePicker {
  /// `null` when the user cancelled.
  Future<PickedFile?> pick();
}

/// `file_picker` implementation. The size is known before reading, so a
/// file over 5 MB is rejected without loading it into memory.
class PlatformDocumentFilePicker implements DocumentFilePicker {
  const PlatformDocumentFilePicker();

  @override
  Future<PickedFile?> pick() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choose a document',
      type: FileType.custom,
      allowedExtensions: DocumentUploadRules.allowedExtensions,
    );
    if (file == null) {
      return null;
    }
    final size = file.lengthSync() ?? await file.length() ?? 0;
    final tooLarge = size > DocumentUploadRules.maxFileBytes;
    final bytes = tooLarge ? null : await file.readAsBytes();
    return PickedFile(
      name: file.name,
      size: bytes?.length ?? size,
      bytes: bytes,
    );
  }
}

final documentFilePickerProvider = Provider<DocumentFilePicker>(
  (ref) => const PlatformDocumentFilePicker(),
);
