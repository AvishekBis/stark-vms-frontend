import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/features/auth/data/auth_models.dart';

void main() {
  group('LoginResponse.fromJson (FR-AUTH-01)', () {
    test('parses token, expiry and user', () {
      final response = LoginResponse.fromJson({
        'accessToken': 'eyJhbGciOi.abc.def',
        'tokenType': 'Bearer',
        'expiresIn': 3600,
        'user': {
          'id': 1,
          'email': 'admin@stark.local',
          'fullName': 'Fleet Admin',
          'role': 'ADMIN',
        },
      });

      expect(response.accessToken, 'eyJhbGciOi.abc.def');
      expect(response.tokenType, 'Bearer');
      expect(response.expiresIn, const Duration(hours: 1));
      expect(response.user.fullName, 'Fleet Admin');
      expect(response.user.role, UserRole.admin);
      expect(response.user.isAdmin, isTrue);
    });

    test(
      'defaults missing tokenType and expiresIn, falls back to email for name',
      () {
        final response = LoginResponse.fromJson({
          'accessToken': 't',
          'tokenType': null,
          'expiresIn': null,
          'user': {
            'id': 2,
            'email': 'staff@stark.local',
            'fullName': null,
            'role': 'STAFF',
          },
        });

        expect(response.tokenType, 'Bearer');
        expect(
          response.expiresIn,
          const Duration(seconds: LoginResponse.defaultExpirySeconds),
        );
        expect(response.user.fullName, 'staff@stark.local');
        expect(response.user.role, UserRole.staff);
      },
    );

    test('unknown role gets the least privileges', () {
      final user = User.fromJson({
        'id': 3,
        'email': 'x@y.z',
        'fullName': 'X',
        'role': 'ROOT',
      });
      expect(user.role, UserRole.staff);
    });

    test('rejects a response without token', () {
      expect(
        () => LoginResponse.fromJson({
          'user': {'id': 1, 'email': 'a@b.c', 'role': 'ADMIN'},
        }),
        throwsFormatException,
      );
    });
  });

  group('AuthSession', () {
    final now = DateTime.utc(2026, 11, 10, 8);
    const response = LoginResponse(
      accessToken: 'token',
      tokenType: 'Bearer',
      expiresIn: Duration(minutes: 60),
      user: User(
        id: 1,
        email: 'admin@stark.local',
        fullName: 'Fleet Admin',
        role: UserRole.admin,
      ),
    );

    test('expires after expiresIn (FR-AUTH-02)', () {
      final session = AuthSession.fromLogin(response, now: now);

      expect(session.expiresAt, DateTime.utc(2026, 11, 10, 9));
      expect(
        session.isExpiredAt(now.add(const Duration(minutes: 59))),
        isFalse,
      );
      expect(session.isExpiredAt(now.add(const Duration(minutes: 60))), isTrue);
    });

    test('survives a JSON round trip for storage', () {
      final session = AuthSession.fromLogin(response, now: now);
      final restored = AuthSession.fromJson(session.toJson());

      expect(restored.accessToken, 'token');
      expect(restored.expiresAt, session.expiresAt);
      expect(restored.user.email, 'admin@stark.local');
      expect(restored.user.role, UserRole.admin);
    });
  });
}
