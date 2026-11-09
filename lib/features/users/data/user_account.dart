import '../../../core/utils/json_readers.dart';
import '../../auth/data/auth_models.dart';

/// `UserResponse` of the user-management endpoints (contract 7.3.1,
/// ADR 0024). Named `UserAccount` because [User] is already the logged-in
/// user of `POST /auth/login` / `GET /auth/me`, whose shape is unchanged.
/// Never contains a password hash.
class UserAccount {
  const UserAccount({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.enabled,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.version = 0,
  });

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      id: JsonReaders.requireInt(json, 'id'),
      email: JsonReaders.requireString(json, 'email'),
      fullName: json['fullName'] as String? ?? '',
      role: UserRole.fromApi(json['role']),
      enabled: JsonReaders.boolOr(json['enabled'], false),
      createdAt: JsonReaders.timestamp(json['createdAt']),
      updatedAt: JsonReaders.timestamp(json['updatedAt']),
      createdBy: json['createdBy'] as String?,
      version: JsonReaders.intOr(json['version'], 0),
    );
  }

  final int id;
  final String email;
  final String fullName;
  final UserRole role;

  /// `false` = disabled: cannot log in, existing tokens stop working.
  final bool enabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// The ADMIN who created the account; `"system"` for the start-up
  /// accounts (`APP_ADMIN_*`, `APP_STAFF_*`). `null` only if the server
  /// omits it.
  final String? createdBy;

  /// Optimistic locking (ADR 0023): sent back in `PUT /users/{id}`.
  final int version;

  bool get isAdmin => role == UserRole.admin;

  /// The full name, or the e-mail when the name is blank.
  String get displayName => fullName.trim().isEmpty ? email : fullName;
}

/// `CreateUserRequest` (`POST /users`).
class CreateUserInput {
  const CreateUserInput({
    required this.email,
    required this.fullName,
    required this.role,
    required this.password,
  });

  static const Set<String> fieldNames = {
    'email',
    'fullName',
    'role',
    'password',
  };

  final String email;
  final String fullName;
  final UserRole role;
  final String password;

  /// The e-mail is sent trimmed and lower-cased (the server stores it so);
  /// the password is sent exactly as typed. No `version` on create.
  Map<String, dynamic> toJson() => {
    'email': email.trim().toLowerCase(),
    'fullName': fullName.trim(),
    'role': role.apiValue,
    'password': password,
  };
}

/// `UpdateUserRequest` (`PUT /users/{id}`). The e-mail cannot be changed,
/// so it is not part of the body.
class UpdateUserInput {
  const UpdateUserInput({
    required this.fullName,
    required this.role,
    required this.enabled,
  });

  static const Set<String> fieldNames = {'fullName', 'role', 'enabled'};

  final String fullName;
  final UserRole role;
  final bool enabled;

  /// Every field is required, `version` included (contract 7.3.3).
  Map<String, dynamic> toUpdateJson(int version) => {
    'fullName': fullName.trim(),
    'role': role.apiValue,
    'enabled': enabled,
    'version': version,
  };
}
