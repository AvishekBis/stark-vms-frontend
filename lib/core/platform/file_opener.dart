import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import 'file_opener_stub.dart'
    if (dart.library.js_interop) 'file_opener_web.dart';

/// Loads a file that needs the bearer token (so a plain link would not work).
typedef FileLoader = Future<BinaryResponse> Function();

/// Shows or saves downloaded bytes in the browser (Blob + object URL).
abstract interface class FileOpener {
  /// Opens the file in a new tab. The tab is opened before [load] runs, so
  /// the browser treats it as a direct reaction to the click (no popup
  /// blocker).
  Future<void> open(
    FileLoader load, {
    required String fileName,
    String? contentType,
  });

  /// Saves the file with [fileName] (an `<a download>` click).
  Future<void> download(
    FileLoader load, {
    required String fileName,
    String? contentType,
  });
}

final fileOpenerProvider = Provider<FileOpener>((ref) => createFileOpener());
