import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/network/page_response.dart';
import '../../../core/network/response_parsing.dart';
import 'user_account.dart';
import 'user_query.dart';

/// User-management endpoints (v2.1, contract 7.3, ADR 0024). ADMIN only:
/// the server answers 403 for STAFF. There is no delete: users are
/// disabled instead.
abstract interface class UserRepository {
  Future<PageResponse<UserAccount>> list(UserQuery query);

  Future<UserAccount> get(int id);

  /// 201; 409 `duplicate-email` (field `email`).
  Future<UserAccount> create(CreateUserInput input);

  /// Sends the loaded [version]. 409 `stale-version`, `self-modification`
  /// or `last-admin`.
  Future<UserAccount> update(
    int id,
    UpdateUserInput input, {
    required int version,
  });

  /// Admin reset (`POST /users/{id}/password`) → 204. The user's existing
  /// sessions end on their next request.
  Future<void> resetPassword(int id, {required String newPassword});
}

class ApiUserRepository implements UserRepository {
  const ApiUserRepository(this._client);

  static const String _basePath = '/users';

  final ApiClient _client;

  @override
  Future<PageResponse<UserAccount>> list(UserQuery query) async {
    final body = await _client.get(
      _basePath,
      queryParameters: query.toQueryParameters(),
    );
    return ResponseParsing.parse(
      () => PageResponse.fromJson(
        ResponseParsing.object(body),
        UserAccount.fromJson,
      ),
    );
  }

  @override
  Future<UserAccount> get(int id) async =>
      _user(await _client.get('$_basePath/$id'));

  @override
  Future<UserAccount> create(CreateUserInput input) async =>
      _user(await _client.post(_basePath, body: input.toJson()));

  @override
  Future<UserAccount> update(
    int id,
    UpdateUserInput input, {
    required int version,
  }) async => _user(
    await _client.put('$_basePath/$id', body: input.toUpdateJson(version)),
  );

  @override
  Future<void> resetPassword(int id, {required String newPassword}) async {
    await _client.post(
      '$_basePath/$id/password',
      body: {'newPassword': newPassword},
    );
  }

  static UserAccount _user(Object? body) => ResponseParsing.parse(
    () => UserAccount.fromJson(ResponseParsing.object(body)),
  );
}

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => ApiUserRepository(ref.watch(apiClientProvider)),
);
