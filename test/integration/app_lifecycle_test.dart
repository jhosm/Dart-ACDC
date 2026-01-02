import 'dart:convert';
import 'dart:io';

import 'package:dart_acdc/dart_acdc.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import '../helpers/fake_oauth_server.dart';

/// Integration tests for app lifecycle scenarios during token refresh.
///
/// Tests resilience and correctness of token refresh when:
/// - App is backgrounded (simulated with delays)
/// - Network errors occur during refresh
/// - App is killed/interrupted during refresh (simulated with errors)
///
/// Note: True platform-specific lifecycle events (app backgrounding, OS suspension)
/// cannot be fully tested in Dart integration tests and require platform-specific
/// testing on iOS/Android.
void main() {
  group('App Lifecycle During Token Refresh', () {
    late FakeOAuthServer oauthServer;
    late FakeApiServer apiServer;
    late TestTokenProvider tokenProvider;

    setUp(() async {
      oauthServer = FakeOAuthServer();
      await oauthServer.start();

      apiServer = FakeApiServer();
      await apiServer.start();

      tokenProvider = TestTokenProvider();

      // Reset servers for each test
      oauthServer.reset();
      apiServer.reset();
    });

    tearDown(() async {
      await oauthServer.stop();
      await apiServer.stop();
    });

    test('token refresh completes despite delay (simulates backgrounding)',
        () async {
      // This simulates the scenario where the app is backgrounded during
      // token refresh, but the OS allows the refresh to continue.

      const clientId = 'test-client-id';

      // Configure server with delay to simulate slow network or backgrounding
      oauthServer
        ..setResponseDelay(const Duration(milliseconds: 500))
        ..respondWithSuccess(
          accessToken: 'refreshed-access-token',
          refreshToken: 'refreshed-refresh-token',
        );

      // Set up expiring token to trigger proactive refresh
      final expiry = DateTime.now().toUtc().add(const Duration(seconds: 30));
      tokenProvider.initializeTokens(
        accessToken: 'expiring-token',
        refreshToken: 'original-refresh-token',
        accessExpiry: expiry,
      );

      final dio = const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withTokenRefreshEndpoint(
            url: oauthServer.tokenUrl,
            clientId: clientId,
          )
          .build();

      // Configure API server to return success
      apiServer.respondWith(200, {'result': 'success'});

      // Make request - refresh should complete despite delay
      final response = await dio.get<Map<String, dynamic>>('/test');
      expect(response.statusCode, 200);

      // Verify refresh completed successfully
      expect(oauthServer.refreshCallCount, 1);
      expect(
        await tokenProvider.getAccessToken(),
        'refreshed-access-token',
        reason: 'Token refresh should complete despite delay',
      );
      expect(
        await tokenProvider.getRefreshToken(),
        'refreshed-refresh-token',
        reason: 'Refresh token should be updated',
      );
    });

    test('network error during refresh does NOT clear tokens', () async {
      // This simulates network changes (WiFi to cellular) causing connection
      // failure during token refresh. Per the design, network errors during
      // refresh should NOT clear tokens since they're transient.

      const clientId = 'test-client-id';

      // Don't start the OAuth server - this will cause connection refused
      await oauthServer.stop();

      // Set up EXPIRED token to force refresh (not just expiring soon)
      final expiry = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      tokenProvider.initializeTokens(
        accessToken: 'expired-token',
        refreshToken: 'original-refresh-token',
        accessExpiry: expiry,
      );

      final dio = const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withTokenRefreshEndpoint(
            url: 'http://localhost:59999', // Non-existent port
            clientId: clientId,
          )
          .build();

      // Configure API server to require valid auth - return 401 if no auth header
      apiServer.setDynamicHandler((request) {
        if (request.headers['authorization'] == null) {
          return (401, {'error': 'unauthorized'});
        }
        return (200, {'result': 'success'});
      });

      // Make request - should fail with network exception during refresh
      // (refresh fails, no valid token available, request proceeds without auth,
      // but then fails with network error when trying to refresh)
      await expectLater(
        dio.get<Map<String, dynamic>>('/test'),
        throwsA(isA<AcdcNetworkException>()),
        reason: 'Network errors during refresh should throw exception',
      );

      // Verify tokens were NOT cleared (network errors are transient)
      expect(
        await tokenProvider.getAccessToken(),
        'expired-token',
        reason: 'Tokens should NOT be cleared after network error (transient)',
      );
      expect(
        await tokenProvider.getRefreshToken(),
        'original-refresh-token',
        reason: 'Refresh token should NOT be cleared after network error',
      );
    });

    test('auth error clears tokens, can retry after app restart', () async {
      // This simulates the scenario where the app gets an auth error (e.g.,
      // invalid_grant) during refresh, which clears tokens. After app restart
      // with new valid tokens, refresh should work.

      const clientId = 'test-client-id';

      // First attempt: Server returns auth error
      oauthServer.respondWithOAuthError(
        error: 'invalid_grant',
        errorDescription: 'Refresh token expired',
      );

      // Set up EXPIRED token to force refresh
      final expiry = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      tokenProvider.initializeTokens(
        accessToken: 'old-access-token',
        refreshToken: 'old-refresh-token',
        accessExpiry: expiry,
      );

      final dio = const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withTokenRefreshEndpoint(
            url: oauthServer.tokenUrl,
            clientId: clientId,
          )
          .build();

      // Configure API server to require valid auth - return 401 if no auth header
      apiServer.setDynamicHandler((request) {
        if (request.headers['authorization'] == null) {
          return (401, {'error': 'unauthorized'});
        }
        return (200, {'result': 'success'});
      });

      // First request - refresh should fail with auth error
      await expectLater(
        dio.get<Map<String, dynamic>>('/test'),
        throwsA(isA<AcdcAuthException>()),
        reason: 'Auth errors during refresh should throw AcdcAuthException',
      );

      // Verify tokens were cleared after auth error
      expect(
        await tokenProvider.getAccessToken(),
        isNull,
        reason: 'Tokens should be cleared after auth error',
      );
      expect(
        await tokenProvider.getRefreshToken(),
        isNull,
        reason: 'Refresh token should be cleared after auth error',
      );

      // Simulate app restart - user logs in again with new tokens
      tokenProvider.initializeTokens(
        accessToken: 'new-access-after-login',
        refreshToken: 'new-valid-refresh-token',
        accessExpiry: expiry,
      );

      // Configure server to succeed on next attempt
      oauthServer.respondWithSuccess(
        accessToken: 'refreshed-access-token',
        refreshToken: 'refreshed-refresh-token',
      );

      // Second request - should trigger new refresh and succeed
      final response = await dio.get<Map<String, dynamic>>('/test');
      expect(response.statusCode, 200);

      // Verify tokens were updated
      expect(
        await tokenProvider.getAccessToken(),
        'refreshed-access-token',
        reason: 'New refresh should succeed with valid refresh token',
      );
      expect(
        await tokenProvider.getRefreshToken(),
        'refreshed-refresh-token',
        reason: 'Refresh token should be updated',
      );
      expect(
        oauthServer.refreshCallCount,
        2,
        reason: 'Two refresh attempts should have occurred',
      );
    });

    test('concurrent requests wait for delayed refresh (backgrounding scenario)',
        () async {
      // This tests that multiple concurrent requests properly wait for a
      // delayed refresh to complete (e.g., when app is backgrounded but
      // refresh continues).

      const clientId = 'test-client-id';

      // Configure server with delay
      oauthServer
        ..setResponseDelay(const Duration(milliseconds: 200))
        ..respondWithSuccess(
          accessToken: 'refreshed-token',
        );

      // Set up expiring token
      final expiry = DateTime.now().toUtc().add(const Duration(seconds: 30));
      tokenProvider.initializeTokens(
        accessToken: 'expiring-token',
        refreshToken: 'refresh-token',
        accessExpiry: expiry,
      );

      final dio = const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withTokenRefreshEndpoint(
            url: oauthServer.tokenUrl,
            clientId: clientId,
          )
          .build();

      // Configure API server
      apiServer.respondWith(200, {'result': 'success'});

      // Start multiple concurrent requests
      final futures = [
        dio.get<Map<String, dynamic>>('/test1'),
        dio.get<Map<String, dynamic>>('/test2'),
        dio.get<Map<String, dynamic>>('/test3'),
      ];

      // All should complete successfully
      final responses = await Future.wait(futures);
      expect(responses.every((r) => r.statusCode == 200), isTrue);

      // Verify refresh happened only once
      expect(
        oauthServer.refreshCallCount,
        1,
        reason: 'Refresh should happen only once despite concurrent requests',
      );

      // Verify all requests used the refreshed token
      expect(
        await tokenProvider.getAccessToken(),
        'refreshed-token',
        reason: 'All requests should use the refreshed token',
      );
    });

    test('server error during refresh does NOT clear tokens', () async {
      // This tests that server errors (5xx) during refresh are properly
      // classified and tokens are NOT cleared (transient errors).

      const clientId = 'test-client-id';

      // Configure server to return 500 error
      oauthServer.respondWithServerError();

      // Set up EXPIRED token to force refresh
      final expiry = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      tokenProvider.initializeTokens(
        accessToken: 'expired-token',
        refreshToken: 'refresh-token',
        accessExpiry: expiry,
      );

      final dio = const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withTokenRefreshEndpoint(
            url: oauthServer.tokenUrl,
            clientId: clientId,
          )
          .build();

      // Configure API server to require valid auth - return 401 if no auth header
      apiServer.setDynamicHandler((request) {
        if (request.headers['authorization'] == null) {
          return (401, {'error': 'unauthorized'});
        }
        return (200, {'result': 'success'});
      });

      // Make request - should fail with server exception
      await expectLater(
        dio.get<Map<String, dynamic>>('/test'),
        throwsA(isA<AcdcServerException>()),
        reason: '500 error during refresh should throw AcdcServerException',
      );

      // Verify tokens were NOT cleared (server errors are transient)
      expect(
        await tokenProvider.getAccessToken(),
        'expired-token',
        reason: 'Tokens should NOT be cleared after server error (transient)',
      );
      expect(
        await tokenProvider.getRefreshToken(),
        'refresh-token',
        reason: 'Refresh token should NOT be cleared after server error',
      );
    });
  });
}

/// Test implementation of TokenProvider.
class TestTokenProvider implements TokenProvider {
  String? _accessToken;
  String? _refreshToken;
  DateTime? _accessExpiry;
  DateTime? _refreshExpiry;

  /// Helper method to initialize tokens for tests.
  void initializeTokens({
    required String? accessToken,
    required String? refreshToken,
    DateTime? accessExpiry,
    DateTime? refreshExpiry,
  }) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _accessExpiry = accessExpiry;
    _refreshExpiry = refreshExpiry;
  }

  @override
  Future<String?> getAccessToken() async => _accessToken;

  @override
  Future<String?> getRefreshToken() async => _refreshToken;

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
    _accessToken = accessToken;
    if (refreshToken != null) {
      _refreshToken = refreshToken;
    }
    _accessExpiry = accessExpiry;
    _refreshExpiry = refreshExpiry;
  }

  @override
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _accessExpiry = null;
    _refreshExpiry = null;
  }
}

/// Fake API server for testing.
class FakeApiServer {
  HttpServer? _server;
  int? _port;
  shelf.Request? lastRequest;

  int _responseStatusCode = 200;
  Map<String, dynamic> _responseData = {};
  (int, Map<String, dynamic>) Function(shelf.Request)? _dynamicHandler;

  Future<void> start() async {
    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(_handleRequest);

    _server = await shelf_io.serve(handler, 'localhost', 0);
    _port = _server!.port;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = null;
  }

  String get baseUrl => 'http://localhost:$_port';

  void reset() {
    _responseStatusCode = 200;
    _responseData = {};
    _dynamicHandler = null;
    lastRequest = null;
  }

  void respondWith(int statusCode, Map<String, dynamic> data) {
    _responseStatusCode = statusCode;
    _responseData = data;
    _dynamicHandler = null;
  }

  void setDynamicHandler(
    (int, Map<String, dynamic>) Function(shelf.Request) handler,
  ) {
    _dynamicHandler = handler;
  }

  Future<shelf.Response> _handleRequest(shelf.Request request) async {
    lastRequest = request;

    // Use dynamic handler if set
    if (_dynamicHandler != null) {
      final (status, data) = _dynamicHandler!(request);
      return shelf.Response(
        status,
        body: jsonEncode(data),
        headers: {'content-type': 'application/json'},
      );
    }

    return shelf.Response(
      _responseStatusCode,
      body: jsonEncode(_responseData),
      headers: {'content-type': 'application/json'},
    );
  }
}

