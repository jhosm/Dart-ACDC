import 'dart:convert';
import 'dart:io';

import 'package:dart_acdc/dart_acdc.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import '../helpers/fake_oauth_server.dart';
import '../helpers/mock_network_info.dart';

/// Integration test for TokenProvider exception handling.
///
/// Tests that when TokenProvider methods throw exceptions:
/// - The client handles errors gracefully without crashes
/// - Requests proceed with degraded functionality (no auth)
/// - Token refresh failures are handled appropriately
/// - Logout completes despite storage errors
void main() {
  group('TokenProvider Exception Handling', () {
    late FakeOAuthServer oauthServer;
    late FakeApiServer apiServer;
    late ThrowingTokenProvider tokenProvider;

    setUp(() async {
      oauthServer = FakeOAuthServer();
      await oauthServer.start();

      apiServer = FakeApiServer();
      await apiServer.start();

      tokenProvider = ThrowingTokenProvider();

      // Reset servers for each test
      oauthServer.reset();
      apiServer.reset();
    });

    tearDown(() async {
      await oauthServer.stop();
      await apiServer.stop();
    });

    test('request proceeds without auth when getAccessToken throws', () async {
      // Configure provider to throw on getAccessToken
      tokenProvider.throwOnGetAccessToken = true;

      final dio = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withTokenRefreshEndpoint(
            url: oauthServer.tokenUrl,
            clientId: 'test-client',
          )
          .disableCache()
          .withNetworkInfo(MockNetworkInfo())
          .build();

      // Make request - should succeed without auth header
      apiServer.respondWith(200, {'data': 'success'});
      final response = await dio.get<Map<String, dynamic>>('/test');

      // Verify request succeeded
      expect(response.statusCode, 200);
      expect(response.data, {'data': 'success'});

      // Verify no auth header was sent (graceful degradation)
      expect(apiServer.lastRequest?.headers['authorization'], isNull);
    });

    test('request proceeds without auth when getAccessTokenExpiry throws',
        () async {
      // Configure provider to throw on getAccessTokenExpiry
      tokenProvider.throwOnGetAccessTokenExpiry = true;

      final dio = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withTokenRefreshEndpoint(
            url: oauthServer.tokenUrl,
            clientId: 'test-client',
          )
          .disableCache()
          .withNetworkInfo(MockNetworkInfo())
          .build();

      // Make request - should proceed without proactive refresh
      apiServer.respondWith(200, {'data': 'success'});
      final response = await dio.get<Map<String, dynamic>>('/test');

      // Verify request succeeded
      expect(response.statusCode, 200);

      // Verify no refresh was attempted (couldn't check expiry)
      expect(oauthServer.refreshCallCount, 0);
    });

    test('reactive refresh fails gracefully when getRefreshToken throws',
        () async {
      // Configure provider to return access token but throw on refresh token
      tokenProvider
        ..throwOnGetRefreshToken = true
        ..accessToken = 'test-token';

      final dio = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withTokenRefreshEndpoint(
            url: oauthServer.tokenUrl,
            clientId: 'test-client',
          )
          .disableCache()
          .withNetworkInfo(MockNetworkInfo())
          .build();

      // Return 401 to trigger reactive refresh
      apiServer.respondWith(401, {'error': 'Unauthorized'});

      // Request should fail - the refresh attempt throws an AcdcAuthException
      await expectLater(
        dio.get<Map<String, dynamic>>('/test'),
        throwsA(isA<AcdcAuthException>()),
      );

      // Verify no refresh was attempted (couldn't get refresh token)
      expect(oauthServer.refreshCallCount, 0);
    });

    test('token storage failure degrades gracefully during refresh', () async {
      // Set expiring token to trigger proactive refresh
      final expiry = DateTime.now().toUtc().add(const Duration(seconds: 30));
      tokenProvider
        ..accessToken = 'expiring-token'
        ..refreshToken = 'valid-refresh-token'
        ..accessExpiry = expiry
        ..throwOnSetTokens = true;

      // Configure OAuth server to return new token
      oauthServer.respondWithSuccess(
        accessToken: 'new-token',
      );

      final dio = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withTokenRefreshEndpoint(
            url: oauthServer.tokenUrl,
            clientId: 'test-client',
          )
          .disableCache()
          .withNetworkInfo(MockNetworkInfo())
          .build();

      apiServer.respondWith(200, {'result': 'ok'});

      // Make request - refresh will succeed but token storage will fail
      // The exception is caught in onRequest and request proceeds without auth
      final response = await dio.get<Map<String, dynamic>>('/test');

      // Verify request succeeded (graceful degradation)
      expect(response.statusCode, 200);
      expect(response.data, {'result': 'ok'});

      // Verify refresh was attempted
      expect(oauthServer.refreshCallCount, 1);

      // Verify request proceeded without auth (setTokens failed so no token was stored)
      expect(apiServer.lastRequest?.headers['authorization'], isNull);
    });

    test('logout completes despite clearTokens throwing exception', () async {
      tokenProvider
        ..accessToken = 'active-token'
        ..refreshToken = 'active-refresh'
        ..throwOnClearTokens = true;

      final dio = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withTokenRefreshEndpoint(
            url: oauthServer.tokenUrl,
            clientId: 'test-client',
          )
          .withTokenRevocationEndpoint(oauthServer.revokeUrl)
          .withNetworkInfo(MockNetworkInfo())
          .build();

      // Logout should complete despite clearTokens exception
      await expectLater(dio.auth.logout(), completes);

      // Verify revocation was still attempted (best-effort cleanup)
      expect(oauthServer.revokeCallCount, 2);
    });

    test('all TokenProvider methods throwing results in degraded mode',
        () async {
      // Configure provider to throw on all methods
      tokenProvider
        ..throwOnGetAccessToken = true
        ..throwOnGetRefreshToken = true
        ..throwOnGetAccessTokenExpiry = true
        ..throwOnGetRefreshTokenExpiry = true
        ..throwOnSetTokens = true
        ..throwOnClearTokens = true;

      final dio = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withTokenRefreshEndpoint(
            url: oauthServer.tokenUrl,
            clientId: 'test-client',
          )
          .disableCache()
          .withNetworkInfo(MockNetworkInfo())
          .build();

      // Request should succeed without auth (complete degradation)
      apiServer.respondWith(200, {'data': 'works'});
      final response = await dio.get<Map<String, dynamic>>('/test');

      // Verify request succeeded
      expect(response.statusCode, 200);
      expect(response.data, {'data': 'works'});

      // Verify no auth header (graceful degradation)
      expect(apiServer.lastRequest?.headers['authorization'], isNull);

      // Verify no refresh attempted
      expect(oauthServer.refreshCallCount, 0);
    });

    test('getRefreshTokenExpiry exception does not prevent token refresh',
        () async {
      // Set expiring access token
      final expiry = DateTime.now().toUtc().add(const Duration(seconds: 30));
      tokenProvider
        ..accessToken = 'expiring-token'
        ..refreshToken = 'valid-refresh-token'
        ..accessExpiry = expiry
        ..throwOnGetRefreshTokenExpiry = true;

      oauthServer.respondWithSuccess(
        accessToken: 'refreshed-token',
      );

      final dio = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withTokenRefreshEndpoint(
            url: oauthServer.tokenUrl,
            clientId: 'test-client',
          )
          .disableCache()
          .withNetworkInfo(MockNetworkInfo())
          .build();

      apiServer.respondWith(200, {'result': 'ok'});
      final response = await dio.get<Map<String, dynamic>>('/test');

      // Verify request succeeded
      expect(response.statusCode, 200);

      // Verify refresh was attempted (refresh expiry check didn't block it)
      expect(oauthServer.refreshCallCount, 1);
    });

    test('mixed exceptions allow partial functionality', () async {
      // Access token works, but refresh token throws
      tokenProvider
        ..accessToken = 'valid-token'
        ..throwOnGetRefreshToken = true;

      final dio = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withTokenRefreshEndpoint(
            url: oauthServer.tokenUrl,
            clientId: 'test-client',
          )
          .disableCache()
          .withNetworkInfo(MockNetworkInfo())
          .build();

      // Request should succeed with auth header
      apiServer.respondWith(200, {'data': 'success'});
      final response = await dio.get<Map<String, dynamic>>('/test');

      // Verify request succeeded with auth
      expect(response.statusCode, 200);
      expect(
        apiServer.lastRequest?.headers['authorization'],
        'Bearer valid-token',
      );
    });
  });
}

/// TokenProvider implementation that throws exceptions on demand.
class ThrowingTokenProvider implements TokenProvider {
  // Control flags for which methods should throw
  bool throwOnGetAccessToken = false;
  bool throwOnGetRefreshToken = false;
  bool throwOnGetAccessTokenExpiry = false;
  bool throwOnGetRefreshTokenExpiry = false;
  bool throwOnSetTokens = false;
  bool throwOnClearTokens = false;

  // Actual token storage (when not throwing)
  String? accessToken;
  String? refreshToken;
  DateTime? accessExpiry;
  DateTime? refreshExpiry;

  @override
  Future<String?> getAccessToken() async {
    if (throwOnGetAccessToken) {
      throw Exception('TokenProvider storage error: cannot read access token');
    }
    return accessToken;
  }

  @override
  Future<String?> getRefreshToken() async {
    if (throwOnGetRefreshToken) {
      throw Exception('TokenProvider storage error: cannot read refresh token');
    }
    return refreshToken;
  }

  @override
  Future<DateTime?> getAccessTokenExpiry() async {
    if (throwOnGetAccessTokenExpiry) {
      throw Exception(
        'TokenProvider storage error: cannot read access token expiry',
      );
    }
    return accessExpiry;
  }

  @override
  Future<DateTime?> getRefreshTokenExpiry() async {
    if (throwOnGetRefreshTokenExpiry) {
      throw Exception(
        'TokenProvider storage error: cannot read refresh token expiry',
      );
    }
    return refreshExpiry;
  }

  @override
  Future<void> setTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? accessExpiry,
    DateTime? refreshExpiry,
  }) async {
    if (throwOnSetTokens) {
      throw Exception('TokenProvider storage error: cannot write tokens');
    }
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    this.accessExpiry = accessExpiry;
    this.refreshExpiry = refreshExpiry;
  }

  @override
  Future<void> clearTokens() async {
    if (throwOnClearTokens) {
      throw Exception('TokenProvider storage error: cannot clear tokens');
    }
    accessToken = null;
    refreshToken = null;
    accessExpiry = null;
    refreshExpiry = null;
  }
}

/// Fake API server for testing.
class FakeApiServer {
  HttpServer? _server;
  int? _port;
  shelf.Request? lastRequest;

  int _responseStatusCode = 200;
  Map<String, dynamic> _responseData = {};

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
    lastRequest = null;
  }

  void respondWith(int statusCode, Map<String, dynamic> data) {
    _responseStatusCode = statusCode;
    _responseData = data;
  }

  Future<shelf.Response> _handleRequest(shelf.Request request) async {
    lastRequest = request;

    return shelf.Response(
      _responseStatusCode,
      body: jsonEncode(_responseData),
      headers: {'content-type': 'application/json'},
    );
  }
}
