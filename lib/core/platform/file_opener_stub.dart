import 'file_opener.dart';

/// Non-web builds (tests on the Dart VM): files cannot be shown.
FileOpener createFileOpener() => const UnsupportedFileOpener();

class UnsupportedFileOpener implements FileOpener {
  const UnsupportedFileOpener();

  @override
  Future<void> open(
    FileLoader load, {
    required String fileName,
    String? contentType,
  }) {
    throw UnsupportedError('Opening files is only supported on the web.');
  }

  @override
  Future<void> download(
    FileLoader load, {
    required String fileName,
    String? contentType,
  }) {
    throw UnsupportedError('Downloading files is only supported on the web.');
  }
}
