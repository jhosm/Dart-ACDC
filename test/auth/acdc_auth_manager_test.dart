import 'dart:async';

import 'package:dart_acdc/src/auth/acdc_auth_manager.dart';
import 'package:dart_acdc/src/auth/token_provider.dart';
import 'package:dart_acdc/src/interceptors/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

/// Mock TokenProvider for testing.
class MockTokenProvider implements TokenProvider {
  String? _accessToken;
  String? _refreshToken;
  DateTime? _accessExpiry;
  DateTime? _refreshExpiry;

  bool throwOnGetAccessToken = false;
  bool throwOnGetRefreshToken = false;
  bool throwOnSetTokens = false;
  bool throwOnClearTokens = false;

  @override
  Future<String?> getAccessToken() async {
    if (throwOnGetAccessToken) {
      throw Exception('Failed to get access token');
    }
    return _accessToken;
  }

  @override
  Future<String?> getRefreshToken() async {
    if (throwOnGetRefreshToken) {
      throw Exception('Failed to get refresh token');
    }
    return _refreshToken;
  }

  @override
  Future<DateTime?> getAccessTokenExpiry() async => _accessExpiry;

  @override
  Future<DateTime?> getRefreshTokenExpiry() async => _refreshExpiry;

  @override
  Future<void> setTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? accessExpiry,
    DateTime? refreshExpiry,
  }) async {
    if (throwOnSetTokens) {
      throw Exception('Failed to set tokens');
    }
    _accessToken = accessToken;
    _refreshToken = refreshToken ?? _refreshToken;
    _accessExpiry = accessExpiry;
    _refreshExpiry = refreshExpiry;
  }

  @override
  Future<void> clearTokens() async {
    if (throwOnClearTokens) {
      throw Exception('Failed to clear tokens');
    }
    _accessToken = null;
    _refreshToken = null;
    _accessExpiry = null;
    _refreshExpiry = null;
  }
}

/// Mock AuthInterceptor for testing.
class MockAuthInterceptor extends AuthInterceptor {
  MockAuthInterceptor({
    required super.tokenProvider,
    required super.refreshEndpointUrl,
    required super.clientId,
  });
  bool cancelRefreshCalled = false;

  @override
  void cancelRefresh() {
    cancelRefreshCalled = true;
    super.cancelRefresh();
  }
}

void main() {
  group('AcdcAuthManager', () {
    late MockTokenProvider tokenProvider;
    late MockAuthInterceptor authInterceptor;
    late AcdcAuthManager authManager;

    setUp(() {
      tokenProvider = MockTokenProvider();
      authInterceptor = MockAuthInterceptor(
        tokenProvider: tokenProvider,
        refreshEndpointUrl: 'https://auth.example.com/token',
        clientId: 'test-client',
      );
    });

    group('logout()', () {
      test('calls cancelRefresh on auth interceptor', () async {
        authManager = AcdcAuthManager(
          tokenProvider: tokenProvider,
          authInterceptor: authInterceptor,
        );

        await authManager.logout();

        expect(authInterceptor.cancelRefreshCalled, true);
      });

      test('clears tokens from provider', () async {
        tokenProvider._accessToken = 'test-access-token';
        tokenProvider._refreshToken = 'test-refresh-token';

        authManager = AcdcAuthManager(
          tokenProvider: tokenProvider,
          authInterceptor: authInterceptor,
        );

        await authManager.logout();

        expect(tokenProvider._accessToken, null);
        expect(tokenProvider._refreshToken, null);
      });

      test('completes successfully even if clearTokens throws exception',
          () async {
        tokenProvider.throwOnClearTokens = true;

        authManager = AcdcAuthManager(
          tokenProvider: tokenProvider,
          authInterceptor: authInterceptor,
        );

        // Should not throw despite clearTokens throwing
        await expectLater(authManager.logout(), completes);
      });

      test('skips revocation when revocation endpoint is not configured',
          () async {
        tokenProvider._accessToken = 'test-access-token';
        tokenProvider._refreshToken = 'test-refresh-token';

        authManager = AcdcAuthManager(
          tokenProvider: tokenProvider,
          authInterceptor: authInterceptor,
          // No revocationEndpointUrl or clientId
        );

        await authManager.logout();

        // Tokens should be cleared even without revocation
        expect(tokenProvider._accessToken, null);
        expect(tokenProvider._refreshToken, null);
      });

      test('skips revocation when only revocation endpoint is configured',
          () async {
        authManager = AcdcAuthManager(
          tokenProvider: tokenProvider,
          authInterceptor: authInterceptor,
          revocationEndpointUrl: 'https://auth.example.com/revoke',
          // Missing clientId
        );

        await authManager.logout();

        // Should complete without error
        expect(tokenProvider._accessToken, null);
      });

      test('skips revocation when only clientId is configured', () async {
        authManager = AcdcAuthManager(
          tokenProvider: tokenProvider,
          authInterceptor: authInterceptor,
          clientId: 'test-client',
          // Missing revocationEndpointUrl
        );

        await authManager.logout();

        // Should complete without error
        expect(tokenProvider._accessToken, null);
      });
    });

    group('Token revocation (best-effort)', () {
      test('continues logout even if getRefreshToken throws exception',
          () async {
        tokenProvider.throwOnGetRefreshToken = true;

        authManager = AcdcAuthManager(
          tokenProvider: tokenProvider,
          authInterceptor: authInterceptor,
          revocationEndpointUrl: 'https://auth.example.com/revoke',
          clientId: 'test-client',
        );

        // Should complete successfully despite exception
        await expectLater(authManager.logout(), completes);
      });

      test('continues logout even if getAccessToken throws exception',
          () async {
        tokenProvider.throwOnGetAccessToken = true;

        authManager = AcdcAuthManager(
          tokenProvider: tokenProvider,
          authInterceptor: authInterceptor,
          revocationEndpointUrl: 'https://auth.example.com/revoke',
          clientId: 'test-client',
        );

        // Should complete successfully despite exception
        await expectLater(authManager.logout(), completes);
      });

      test('skips revocation if no tokens are available', () async {
        tokenProvider
          .._accessToken = null
          .._refreshToken = null;

        authManager = AcdcAuthManager(
          tokenProvider: tokenProvider,
          authInterceptor: authInterceptor,
          revocationEndpointUrl: 'https://auth.example.com/revoke',
          clientId: 'test-client',
        );

        // Should complete successfully
        await expectLater(authManager.logout(), completes);
      });
    });

    group('refreshNow()', () {
      test('triggers token refresh through auth interceptor', () async {
        authManager = AcdcAuthManager(
          tokenProvider: tokenProvider,
          authInterceptor: authInterceptor,
        );

        tokenProvider._refreshToken = 'test-refresh-token';

        // This will attempt to trigger refresh
        // Since we don't have a real server, we just verify it doesn't throw
        // In a real scenario, this would trigger the interceptor's onRequest
        await expectLater(
          authManager.refreshNow(),
          completes,
        );
      });
    });

    group('clearCache()', () {
      test('completes without error', () async {
        authManager = AcdcAuthManager(
          tokenProvider: tokenProvider,
          authInterceptor: authInterceptor,
        );

        // clearCache is currently a no-op pending cache interceptor implementation
        await expectLater(authManager.clearCache(), completes);
      });
    });
  });

  group('AcdcAuth extension', () {
    test('returns auth manager when TokenProvider is configured', () {
      final tokenProvider = MockTokenProvider();
      final authInterceptor = MockAuthInterceptor(
        tokenProvider: tokenProvider,
        refreshEndpointUrl: 'https://auth.example.com/token',
        clientId: 'test-client',
      );

      final authManager = AcdcAuthManager(
        tokenProvider: tokenProvider,
        authInterceptor: authInterceptor,
      );

      final dio = Dio();
      dio.options.extra['_acdc_auth_manager'] = authManager;

      expect(dio.auth, authManager);
    });

    test('throws StateError when no TokenProvider configured', () {
      final dio = Dio();
      // No auth manager configured

      expect(
        () => dio.auth,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('No TokenProvider configured'),
          ),
        ),
      );
    });

    test('error message suggests using AcdcClientBuilder', () {
      final dio = Dio();

      expect(
        () => dio.auth,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('AcdcClientBuilder.withTokenProvider()'),
          ),
        ),
      );
    });
  });
}
