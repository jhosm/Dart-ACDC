import 'package:dart_acdc/src/cache/jwt_utils.dart';
import 'package:test/test.dart';

void main() {
  group('JwtUtils', () {
    group('extractUserId', () {
      test('extracts user ID from sub claim', () {
        // JWT with sub claim: {"sub": "user-123", "exp": 9999999999}
        const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJzdWIiOiJ1c2VyLTEyMyIsImV4cCI6OTk5OTk5OTk5OX0.'
            'Kd-3Qx5PxQvQx5PxQvQx5PxQvQx5PxQvQx5PxQvQxQ';

        final userId = JwtUtils.extractUserId(token);

        expect(userId, equals('user-123'));
      });

      test('extracts user ID from user_id claim when sub is missing', () {
        // JWT with user_id claim: {"user_id": "user-456", "exp": 9999999999}
        const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJ1c2VyX2lkIjoidXNlci00NTYiLCJleHAiOjk5OTk5OTk5OTl9.'
            'someSignature';

        final userId = JwtUtils.extractUserId(token);

        expect(userId, equals('user-456'));
      });

      test('extracts user ID from uid claim when sub and user_id are missing',
          () {
        // JWT with uid claim: {"uid": "user-789", "exp": 9999999999}
        const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJ1aWQiOiJ1c2VyLTc4OSIsImV4cCI6OTk5OTk5OTk5OX0.'
            'someSignature';

        final userId = JwtUtils.extractUserId(token);

        expect(userId, equals('user-789'));
      });

      test('prioritizes sub over user_id', () {
        // JWT with both sub and user_id
        const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJzdWIiOiJ1c2VyLTEyMyIsInVzZXJfaWQiOiJ1c2VyLTQ1NiIsImV4cCI6OTk5OTk5OTk5OX0.'
            'someSignature';

        final userId = JwtUtils.extractUserId(token);

        // Should use sub (highest priority)
        expect(userId, equals('user-123'));
      });

      test('returns null for null token', () {
        final userId = JwtUtils.extractUserId(null);

        expect(userId, isNull);
      });

      test('returns null for empty token', () {
        final userId = JwtUtils.extractUserId('');

        expect(userId, isNull);
      });

      test('returns null for invalid JWT format', () {
        const invalidToken = 'not.a.valid.jwt.token';

        final userId = JwtUtils.extractUserId(invalidToken);

        expect(userId, isNull);
      });

      test('returns null when no user ID claims are present', () {
        // JWT without sub, user_id, or uid: {"name": "John", "exp": 9999999999}
        const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJuYW1lIjoiSm9obiIsImV4cCI6OTk5OTk5OTk5OX0.'
            'someSignature';

        final userId = JwtUtils.extractUserId(token);

        expect(userId, isNull);
      });

      test('returns null for empty sub claim', () {
        // JWT with empty sub: {"sub": "", "exp": 9999999999}
        const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJzdWIiOiIiLCJleHAiOjk5OTk5OTk5OTl9.'
            'someSignature';

        final userId = JwtUtils.extractUserId(token);

        expect(userId, isNull);
      });

      test('handles numeric user IDs', () {
        // JWT with numeric sub: {"sub": 12345, "exp": 9999999999}
        const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJzdWIiOjEyMzQ1LCJleHAiOjk5OTk5OTk5OTl9.'
            'someSignature';

        final userId = JwtUtils.extractUserId(token);

        expect(userId, equals('12345'));
      });
    });

    group('isValidJwt', () {
      test('returns true for valid JWT', () {
        const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJzdWIiOiJ1c2VyLTEyMyIsImV4cCI6OTk5OTk5OTk5OX0.'
            'someSignature';

        final isValid = JwtUtils.isValidJwt(token);

        expect(isValid, isTrue);
      });

      test('returns false for null token', () {
        final isValid = JwtUtils.isValidJwt(null);

        expect(isValid, isFalse);
      });

      test('returns false for empty token', () {
        final isValid = JwtUtils.isValidJwt('');

        expect(isValid, isFalse);
      });

      test('returns false for invalid format', () {
        const invalidToken = 'not-a-jwt';

        final isValid = JwtUtils.isValidJwt(invalidToken);

        expect(isValid, isFalse);
      });
    });

    group('isExpired', () {
      test('returns false for non-expired token', () {
        // Token with far future expiry
        const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJzdWIiOiJ1c2VyLTEyMyIsImV4cCI6OTk5OTk5OTk5OX0.'
            'someSignature';

        final isExpired = JwtUtils.isExpired(token);

        expect(isExpired, isFalse);
      });

      test('returns null for null token', () {
        final isExpired = JwtUtils.isExpired(null);

        expect(isExpired, isNull);
      });

      test('returns null for empty token', () {
        final isExpired = JwtUtils.isExpired('');

        expect(isExpired, isNull);
      });

      test('returns null for invalid JWT', () {
        const invalidToken = 'not-a-jwt';

        final isExpired = JwtUtils.isExpired(invalidToken);

        expect(isExpired, isNull);
      });
    });
  });
}
