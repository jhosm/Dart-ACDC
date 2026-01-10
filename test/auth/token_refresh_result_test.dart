import 'package:dart_acdc/src/auth/token_refresh_result.dart';
import 'package:test/test.dart';

void main() {
  group('TokenRefreshResult', () {
    test('constructor sets required and optional parameters correctly', () {
      final accessExpiry = DateTime.now().add(const Duration(hours: 1));
      final refreshExpiry = DateTime.now().add(const Duration(days: 30));

      final result = TokenRefreshResult(
        accessToken: 'new_access_token',
        refreshToken: 'new_refresh_token',
        accessExpiry: accessExpiry,
        refreshExpiry: refreshExpiry,
      );

      expect(result.accessToken, 'new_access_token');
      expect(result.refreshToken, 'new_refresh_token');
      expect(result.accessExpiry, accessExpiry);
      expect(result.refreshExpiry, refreshExpiry);
    });

    test('constructor handles null optional parameters', () {
      const result = TokenRefreshResult(
        accessToken: 'new_access_token',
      );

      expect(result.accessToken, 'new_access_token');
      expect(result.refreshToken, isNull);
      expect(result.accessExpiry, isNull);
      expect(result.refreshExpiry, isNull);
    });

    test('toString returns correct string representation', () {
      final accessExpiry = DateTime.utc(2023, 1, 1, 12, 0, 0);
      final refreshExpiry = DateTime.utc(2023, 2, 1, 12, 0, 0);

      final result = TokenRefreshResult(
        accessToken: 'new_access_token',
        refreshToken: 'new_refresh_token',
        accessExpiry: accessExpiry,
        refreshExpiry: refreshExpiry,
      );

      expect(
        result.toString(),
        'TokenRefreshResult(hasAccessToken: true, hasRefreshToken: true, accessExpiry: $accessExpiry, refreshExpiry: $refreshExpiry)',
      );
    });

    test('toString returns correct string representation with nulls', () {
      const result = TokenRefreshResult(
        accessToken: 'new_access_token',
      );

      expect(
        result.toString(),
        'TokenRefreshResult(hasAccessToken: true, hasRefreshToken: false, accessExpiry: null, refreshExpiry: null)',
      );
    });
    test('toString handles empty access token', () {
      const result = TokenRefreshResult(
        accessToken: '',
      );

      expect(
        result.toString(),
        'TokenRefreshResult(hasAccessToken: false, hasRefreshToken: false, accessExpiry: null, refreshExpiry: null)',
      );
    });
  });
}
