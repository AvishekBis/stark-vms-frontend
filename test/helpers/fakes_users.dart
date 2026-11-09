import 'package:stark_vms_frontend/core/network/api_exception.dart';
import 'package:stark_vms_frontend/core/network/page_response.dart';
import 'package:stark_vms_frontend/features/auth/data/auth_models.dart';
import 'package:stark_vms_frontend/features/users/data/user_account.dart';
import 'package:stark_vms_frontend/features/users/data/user_query.dart';
import 'package:stark_vms_frontend/features/users/data/user_repository.dart';

import 'fakes_v2.dart';

/// Test-only v2.1 user accounts and an in-memory [UserRepository].

UserAccount testUserAccount({
  int id = 7,
  String email = 'officer2@stark.local',
  String fullName = 'Second Officer',
  UserRole role = UserRole.staff,
  bool enabled = true,
  int version = 0,
  String? createdBy = 'admin@stark.local',
}) {
  return UserAccount(
    id: id,
    email: email,
    fullName: fullName,
    role: role,
    enabled: enabled,
    createdAt: DateTime.utc(2026, 11, 7, 8),
    updatedAt: DateTime.utc(2026, 11, 7, 8),
    createdBy: createdBy,
    version: version,
  );
}

/// The signed-in admin of `sessionFor(adminUser)` (same id 1 and e-mail)
/// as a user account.
UserAccount adminAccount({int version = 0}) => testUserAccount(
  id: 1,
  email: 'admin@stark.local',
  fullName: 'Fleet Admin',
  role: UserRole.admin,
  createdBy: 'system',
  version: version,
);

class FakeUserRepository implements UserRepository {
  FakeUserRepository({List<UserAccount> seed = const []}) : users = [...seed];

  final List<UserAccount> users;
  final List<UserQuery> listQueries = [];
  final List<CreateUserInput> created = [];
  final List<(int, UpdateUserInput, int)> updates = [];
  final List<(int, String)> passwordResets = [];

  /// When set, the matching call fails with this error.
  ApiException? listError;
  ApiException? saveError;
  ApiException? resetError;

  @override
  Future<PageResponse<UserAccount>> list(UserQuery query) async {
    listQueries.add(query);
    final error = listError;
    if (error != null) {
      throw error;
    }
    final search = query.search.toLowerCase();
    final matches = users
        .where(
          (u) =>
              u.email.contains(search) ||
              u.fullName.toLowerCase().contains(search),
        )
        .where((u) => query.role == null || u.role == query.role)
        .where((u) => query.enabled == null || u.enabled == query.enabled)
        .toList();
    return pageOf(matches, page: query.page, size: query.size);
  }

  @override
  Future<UserAccount> get(int id) async => users.firstWhere(
    (u) => u.id == id,
    orElse: () => throw ApiException.fromProblemDetails({'status': 404}),
  );

  @override
  Future<UserAccount> create(CreateUserInput input) async {
    created.add(input);
    final error = saveError;
    if (error != null) {
      throw error;
    }
    final json = input.toJson();
    final user = testUserAccount(
      id: 100 + users.length,
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      role: input.role,
    );
    users.add(user);
    return user;
  }

  @override
  Future<UserAccount> update(
    int id,
    UpdateUserInput input, {
    required int version,
  }) async {
    updates.add((id, input, version));
    final error = saveError;
    if (error != null) {
      throw error;
    }
    final index = users.indexWhere((u) => u.id == id);
    final old = users[index];
    final updated = testUserAccount(
      id: id,
      email: old.email,
      fullName: input.fullName,
      role: input.role,
      enabled: input.enabled,
      version: version + 1,
    );
    users[index] = updated;
    return updated;
  }

  @override
  Future<void> resetPassword(int id, {required String newPassword}) async {
    final error = resetError;
    if (error != null) {
      throw error;
    }
    passwordResets.add((id, newPassword));
  }
}
