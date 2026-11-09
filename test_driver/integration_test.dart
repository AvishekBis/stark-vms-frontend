import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Runs the E2E journey and saves every `binding.takeScreenshot(name)` call
/// as `docs/screenshots/<name>.png` (used in the README).
Future<void> main() => integrationDriver(
  onScreenshot: (name, image, [args]) async {
    final file = File('docs/screenshots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(image);
    return true;
  },
  // Screenshots would otherwise also be written, base64-encoded, into a JSON
  // report under build/.
  responseDataCallback: null,
);
