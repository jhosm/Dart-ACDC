import 'package:dart_acdc/src/security/user_id_extractor.dart';
import 'package:test/test.dart';

void main() {
  group('UserIdExtractor', () {
    test('returns no auth when header is missing', () async {
      const extractor = UserIdExtractor();
      final result = await extractor.extract(null);

      expect(result.hasAuth, isFalse);
      expect(result.userId, isNull);
      expect(result.token, isNull);
    });

    test('returns no auth when header is empty', () async {
      const extractor = UserIdExtractor();
      final result = await extractor.extract('');

      expect(result.hasAuth, isFalse);
    });

    test('returns auth without user ID when token is missing from header',
        () async {
      const extractor = UserIdExtractor();
      final result = await extractor.extract('Bearer ');

      expect(result.hasAuth, isTrue); // Header present but empty token
      expect(result.userId, isNull);
    });

    test('extracts user ID from valid JWT', () async {
      const extractor = UserIdExtractor();
      // encoded {"sub": "user-123"}
      const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
          'eyJzdWIiOiJ1c2VyLTEyMyJ9.'
          'signature';

      final result = await extractor.extract('Bearer $token');

      expect(result.hasAuth, isTrue);
      expect(result.userId, equals('user-123'));
      expect(result.token, equals(token));
    });

    test('extracts from custom provider', () async {
      final extractor = UserIdExtractor(
        userIdProvider: (token) async => 'custom-user',
      );

      final result = await extractor.extract('Bearer any-token');

      expect(result.userId, equals('custom-user'));
    });

    test('falls back to JWT if custom provider fails', () async {
      final extractor = UserIdExtractor(
        userIdProvider: (token) async => throw Exception('error'),
      );

      // encoded {"sub": "fallback-user"}
      const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
          'eyJzdWIiOiJmYWxsYmFjay11c2VyIn0.'
          'signature';

      final result = await extractor.extract('Bearer $token');

      expect(result.userId, equals('fallback-user'));
    });
  });
}
