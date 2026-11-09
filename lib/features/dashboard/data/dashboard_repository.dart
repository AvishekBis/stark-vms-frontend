import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/network/response_parsing.dart';
import 'dashboard_summary.dart';

/// `GET /dashboard/summary` — every dashboard number in one call (FR-DB01).
abstract interface class DashboardRepository {
  Future<DashboardSummary> summary();
}

class ApiDashboardRepository implements DashboardRepository {
  const ApiDashboardRepository(this._client);

  final ApiClient _client;

  @override
  Future<DashboardSummary> summary() async {
    final body = await _client.get('/dashboard/summary');
    return ResponseParsing.parse(
      () => DashboardSummary.fromJson(ResponseParsing.object(body)),
    );
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => ApiDashboardRepository(ref.watch(apiClientProvider)),
);
