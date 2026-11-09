import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'api_client.dart';
import 'session_signals.dart';
import 'slow_request_monitor.dart';

final slowRequestMonitorProvider = ChangeNotifierProvider<SlowRequestMonitor>(
  (ref) => SlowRequestMonitor(threshold: AppConfig.slowRequestThreshold),
);

final accessTokenHolderProvider = Provider<AccessTokenHolder>(
  (ref) => AccessTokenHolder(),
);

final unauthorizedEventsProvider = Provider<UnauthorizedEvents>((ref) {
  final events = UnauthorizedEvents();
  ref.onDispose(events.dispose);
  return events;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenHolder = ref.watch(accessTokenHolderProvider);
  final unauthorizedEvents = ref.watch(unauthorizedEventsProvider);
  return ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    timeout: AppConfig.requestTimeout,
    readAccessToken: () => tokenHolder.token,
    onUnauthorized: unauthorizedEvents.notify,
    slowRequestMonitor: ref.watch(slowRequestMonitorProvider.notifier),
  );
});
