import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'file_opener.dart';

FileOpener createFileOpener() => const WebFileOpener();

/// Uses `package:web`: the bytes become a Blob, the Blob an object URL.
class WebFileOpener implements FileOpener {
  const WebFileOpener();

  /// Object URLs are released after this delay (the tab has loaded by then).
  static const Duration _revokeAfter = Duration(minutes: 1);

  static const String _fallbackType = 'application/octet-stream';

  @override
  Future<void> open(
    FileLoader load, {
    required String fileName,
    String? contentType,
  }) async {
    // Opened synchronously inside the click, so it is not a blocked popup.
    final tab = web.window.open('', '_blank');
    try {
      final file = await load();
      final url = _objectUrl(file.bytes, contentType ?? file.contentType);
      if (tab == null) {
        _clickDownload(url, file.fileName ?? fileName);
      } else {
        tab.location.href = url;
      }
      _revokeLater(url);
    } catch (_) {
      tab?.close();
      rethrow;
    }
  }

  @override
  Future<void> download(
    FileLoader load, {
    required String fileName,
    String? contentType,
  }) async {
    final file = await load();
    final url = _objectUrl(file.bytes, contentType ?? file.contentType);
    _clickDownload(url, fileName);
    _revokeLater(url);
  }

  static String _objectUrl(Uint8List bytes, String? contentType) {
    final blob = web.Blob(
      <JSAny>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: contentType ?? _fallbackType),
    );
    return web.URL.createObjectURL(blob);
  }

  static void _clickDownload(String url, String fileName) {
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName;
    anchor.style.display = 'none';
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }

  static void _revokeLater(String url) {
    Timer(_revokeAfter, () => web.URL.revokeObjectURL(url));
  }
}
