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
  bool forceRefreshCalled = false;

  @override
  void cancelRefresh() {
    cancelRefreshCalled = true;
    super.cancelRefresh();
  }

  @override
  Future<void> forceRefresh() async {
    forceRefreshCalled = true;
    // Don't call super to avoid actual network request in tests
  }
}

/// Interceptor for capturing HTTP requests in tests.
class RequestCaptureInterceptor extends Interceptor {
  final List<Map<String, dynamic>> capturedRequests = [];

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    capturedRequests.add({
      'path': options.path,
      'data': options.data,
      'method': options.method,
      'contentType': options.contentType,
      'headers': options.headers,
    });
    // Return success response
    handler.resolve(
      Response(
        requestOptions: options,
        statusCode: 200,
      ),
    );
  }
}

/// Mock AuthInterceptor that throws on forceRefresh.
class _ThrowingAuthInterceptor extends AuthInterceptor {
  _ThrowingAuthInterceptor({
    required super.tokenProvider,
    required super.refreshEndpointUrl,
    required super.clientId,
  });

  @override
  Future<void> forceRefresh() async {
    throw Exception('Simulated refresh failure');
  }
}

/// Mock AuthInterceptor that counts forceRefresh calls.
class _CountingAuthInterceptor extends AuthInterceptor {
  _CountingAuthInterceptor({
    required super.tokenProvider,
    required super.refreshEndpointUrl,
    required super.clientId,
    required this.onForceRefresh,
  });

  final void Function() onForceRefresh;

  @override
  Future<void> forceRefresh() async {
    onForceRefresh();
    // Don't call super to avoid network request
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
        tokenProvider
          .._accessToken = 'test-access-token'
          .._refreshToken = 'test-refresh-token';

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
        tokenProvider
          .._accessToken = 'test-access-token'
          .._refreshToken = 'test-refresh-token';

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

      test(
          'revocation request includes token, token_type_hint, and client_id parameters',
          () async {
        final captureInterceptor = RequestCaptureInterceptor();
        final mockHttpClient = Dio()..interceptors.add(captureInterceptor);

        tokenProvider
          .._accessToken = 'test-access-token'
          .._refreshToken = 'test-refresh-token';

        authManager = AcdcAuthManager(
          tokenProvider: tokenProvider,
          authInterceptor: authInterceptor,
          revocationEndpointUrl: 'https://auth.example.com/revoke',
          clientId: 'test-client-id',
          httpClient: mockHttpClient,
        );

        await authManager.logout();

        // Should have made two revocation requests (refresh token first, then access token)
        expect(captureInterceptor.capturedRequests.length, 2);

        // Verify refresh token revocation request
        final refreshTokenRequest = captureInterceptor.capturedRequests[0];
        expect(refreshTokenRequest['path'], 'https://auth.example.com/revoke');
        expect(refreshTokenRequest['method'], 'POST');
        expect(
          refreshTokenRequest['contentType'],
          'application/x-www-form-urlencoded',
        );
        expect(
          (refreshTokenRequest['headers'] as Map)['Accept'],
          'application/json',
        );
        expect(refreshTokenRequest['data'], {
          'token': 'test-refresh-token',
          'token_type_hint': 'refresh_token',
          'client_id': 'test-client-id',
        });

        // Verify access token revocation request
        final accessTokenRequest = captureInterceptor.capturedRequests[1];
        expect(accessTokenRequest['path'], 'https://auth.example.com/revoke');
        expect(accessTokenRequest['method'], 'POST');
        expect(
          accessTokenRequest['contentType'],
          'application/x-www-form-urlencoded',
        );
        expect(
          (accessTokenRequest['headers'] as Map)['Accept'],
          'application/json',
        );
        expect(accessTokenRequest['data'], {
          'token': 'test-access-token',
          'token_type_hint': 'access_token',
          'client_id': 'test-client-id',
        });
      });
    });

    group('refreshNow()', () {
      test('calls forceRefresh on auth interceptor', () async {
        authManager = AcdcAuthManager(
          tokenProvider: tokenProvider,
          authInterceptor: authInterceptor,
        );

        await authManager.refreshNow();

        expect(authInterceptor.forceRefreshCalled, true);
      });

      test('throws StateError when authentication is disabled', () async {
        authManager = AcdcAuthManager(
          tokenProvider: tokenProvider,
          authInterceptor: null, // No auth configured
        );

        await expectLater(
          authManager.refreshNow(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Authentication is disabled'),
            ),
          ),
        );

        // Verify that forceRefresh was actually called on the interceptor
        expect(authInterceptor.forceRefreshCalled, true);
      });

      test('forces refresh even when access token is still valid', () async {
        authManager = AcdcAuthManager(
          tokenProvider: tokenProvider,
          authInterceptor: authInterceptor,
        );

        // Set a valid token that won't expire for a long time
        tokenProvider
          .._accessToken = 'valid-token'
          .._refreshToken = 'refresh-token'
          .._accessExpiry =
              DateTime.now().toUtc().add(const Duration(hours: 24));

        await authManager.refreshNow();

        // Verify that forceRefresh was called despite valid token
        expect(authInterceptor.forceRefreshCalled, true);
      });

      test('propagates exceptions from forceRefresh', () async {
        // Create a mock that throws on forceRefresh
        final throwingInterceptor = _ThrowingAuthInterceptor(
          tokenProvider: tokenProvider,
          refreshEndpointUrl: 'https://auth.example.com/token',
          clientId: 'test-client',
        );

        authManager = AcdcAuthManager(
          tokenProvider: tokenProvider,
          authInterceptor: throwingInterceptor,
        );

        await expectLater(
          authManager.refreshNow(),
          throwsA(isA<Exception>()),
        );
      });

      test('queues concurrent refreshNow calls properly', () async {
        var forceRefreshCallCount = 0;
        final countingInterceptor = _CountingAuthInterceptor(
          tokenProvider: tokenProvider,
          refreshEndpointUrl: 'https://auth.example.com/token',
          clientId: 'test-client',
          onForceRefresh: () => forceRefreshCallCount++,
        );

        authManager = AcdcAuthManager(
          tokenProvider: tokenProvider,
          authInterceptor: countingInterceptor,
        );

        // Start multiple concurrent refresh calls
        await Future.wait([
          authManager.refreshNow(),
          authManager.refreshNow(),
          authManager.refreshNow(),
        ]);

        // All calls should complete and forceRefresh should be called
        expect(forceRefreshCallCount, greaterThan(0));
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
