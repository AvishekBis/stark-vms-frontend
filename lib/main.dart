import 'package:flutter_web_plugins/url_strategy.dart';

import 'bootstrap.dart';

Future<void> main() async {
  usePathUrlStrategy();
  await bootstrap();
}
