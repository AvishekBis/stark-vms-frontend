/// User roles (section 4 of the guideline).
enum UserRole {
  admin('ADMIN', 'Admin'),
  staff('STAFF', 'Staff');

  const UserRole(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// Unknown roles get the least privileges.
  static UserRole fromApi(Object? value) {
    for (final role in values) {
      if (role.apiValue == value) {
        return role;
      }
    }
    return UserRole.staff;
  }
}

/// The logged-in user, from `user` in the login response and `GET /auth/me`.
class User {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final email = json['email'] as String? ?? '';
    final fullName = (json['fullName'] as String?)?.trim();
    return User(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: email,
      fullName: fullName == null || fullName.isEmpty ? email : fullName,
      role: UserRole.fromApi(json['role']),
    );
  }

  final int id;
  final String email;
  final String fullName;
  final UserRole role;

  bool get isAdmin => role == UserRole.admin;

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'fullName': fullName,
    'role': role.apiValue,
  };
}

/// `POST /auth/login` 200 body.
class LoginResponse {
  const LoginResponse({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final token = json['accessToken'];
    if (token is! String || token.isEmpty) {
      throw const FormatException('Login response has no accessToken.');
    }
    final user = json['user'];
    if (user is! Map<String, dynamic>) {
      throw const FormatException('Login response has no user.');
    }
    return LoginResponse(
      accessToken: token,
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      expiresIn: Duration(
        seconds: (json['expiresIn'] as num?)?.toInt() ?? defaultExpirySeconds,
      ),
      user: User.fromJson(user),
    );
  }

  /// Contract default: 60 minutes.
  static const int defaultExpirySeconds = 3600;

  final String accessToken;
  final String tokenType;
  final Duration expiresIn;
  final User user;
}

/// A session persisted between page reloads.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.expiresAt,
    required this.user,
  });

  factory AuthSession.fromLogin(
    LoginResponse response, {
    required DateTime now,
  }) {
    return AuthSession(
      accessToken: response.accessToken,
      expiresAt: now.toUtc().add(response.expiresIn),
      user: response.user,
    );
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final expiresAt = DateTime.tryParse(json['expiresAt'] as String? ?? '');
    final user = json['user'];
    final token = json['accessToken'];
    if (expiresAt == null ||
        user is! Map<String, dynamic> ||
        token is! String) {
      throw const FormatException('Stored session is incomplete.');
    }
    return AuthSession(
      accessToken: token,
      expiresAt: expiresAt,
      user: User.fromJson(user),
    );
  }

  final String accessToken;
  final DateTime expiresAt;
  final User user;

  bool isExpiredAt(DateTime now) => !now.toUtc().isBefore(expiresAt.toUtc());

  AuthSession copyWith({User? user}) {
    return AuthSession(
      accessToken: accessToken,
      expiresAt: expiresAt,
      user: user ?? this.user,
    );
  }

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'user': user.toJson(),
  };
}
