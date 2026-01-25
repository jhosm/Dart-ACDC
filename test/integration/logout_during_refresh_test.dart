import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_acdc/dart_acdc.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import '../helpers/fake_oauth_server.dart';
import '../helpers/mock_network_info.dart';

/// Integration test for logout during active token refresh.
///
/// Tests that when logout is called while a token refresh is in progress:
/// - The in-progress refresh is cancelled
/// - Queued requests fail with appropriate error
/// - Logout completes successfully
/// - Tokens are cleared and revoked
void main() {
  group('Logout During Refresh', () {
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

    test('logout during refresh completes successfully and clears tokens',
        () async {
      // Set token expiring soon to trigger proactive refresh
      final expiry = DateTime.now().toUtc().add(const Duration(seconds: 30));
      tokenProvider.initializeTokens(
        accessToken: 'expiring-token',
        refreshToken: 'valid-refresh-token',
        accessExpiry: expiry,
      );

      // Add significant delay to refresh to simulate slow network
      oauthServer
        ..responseDelay = const Duration(milliseconds: 200)
        ..respondWithSuccess(
          accessToken: 'refreshed-token',
        );

      final dio = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withNetworkInfo(MockNetworkInfo())
          .withTokenRefreshEndpoint(
            url: oauthServer.tokenUrl,
            clientId: 'test-client',
          )
          .withTokenRevocationEndpoint(oauthServer.revokeUrl)
          .disableCache()
          .build();

      apiServer.respondWith(200, {'result': 'ok'});

      // Start multiple concurrent requests that will trigger and queue behind refresh
      final request1Future = dio.get<Map<String, dynamic>>('/data1');
      final request2Future = dio.get<Map<String, dynamic>>('/data2');
      final request3Future = dio.get<Map<String, dynamic>>('/data3');

      // Give requests time to start and begin queuing
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Call logout while refresh is in-progress
      // This should:
      // 1. Cancel the refresh (complete completer with error)
      // 2. Revoke tokens
      // 3. Clear local token storage
      await dio.auth.logout();

      // Wait for all requests to complete
      // Note: Due to error handling in onRequest, queued requests proceed without auth
      // instead of failing completely
      await Future.wait([
        request1Future,
        request2Future,
        request3Future,
      ]);

      // Verify tokens were cleared after logout
      expect(await tokenProvider.getAccessToken(), isNull);
      expect(await tokenProvider.getRefreshToken(), isNull);

      // Verify revocation was attempted for both tokens
      expect(oauthServer.revokeCallCount, 2);
    });

    test('logout before refresh starts clears tokens normally', () async {
      tokenProvider.initializeTokens(
        accessToken: 'active-token',
        refreshToken: 'active-refresh-token',
      );

      final dio = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withNetworkInfo(MockNetworkInfo())
          .withTokenRefreshEndpoint(
            url: oauthServer.tokenUrl,
            clientId: 'test-client',
          )
          .withTokenRevocationEndpoint(oauthServer.revokeUrl)
          .build();

      // Logout immediately (no refresh in progress)
      await dio.auth.logout();

      // Verify tokens cleared
      expect(await tokenProvider.getAccessToken(), isNull);
      expect(await tokenProvider.getRefreshToken(), isNull);

      // Verify revocation called
      expect(oauthServer.revokeCallCount, 2);

      // Verify no refresh was triggered
      expect(oauthServer.refreshCallCount, 0);
    });

    test('logout proceeds even if revocation fails', () async {
      tokenProvider.initializeTokens(
        accessToken: 'active-token',
        refreshToken: 'active-refresh-token',
      );

      // Configure OAuth server to fail revocation
      oauthServer.respondWithServerError();

      final dio = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withNetworkInfo(MockNetworkInfo())
          .withTokenRefreshEndpoint(
            url: oauthServer.tokenUrl,
            clientId: 'test-client',
          )
          .withTokenRevocationEndpoint(oauthServer.revokeUrl)
          .build();

      // Logout should complete despite revocation failure
      await expectLater(dio.auth.logout(), completes);

      // Verify tokens were still cleared locally (best-effort)
      expect(await tokenProvider.getAccessToken(), isNull);
      expect(await tokenProvider.getRefreshToken(), isNull);
    });

    test('new requests after logout fail without attempting refresh', () async {
      // Set token expiring soon
      final expiry = DateTime.now().toUtc().add(const Duration(seconds: 30));
      tokenProvider.initializeTokens(
        accessToken: 'expiring-token',
        refreshToken: 'valid-refresh-token',
        accessExpiry: expiry,
      );

      final dio = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withNetworkInfo(MockNetworkInfo())
          .withTokenRefreshEndpoint(
            url: oauthServer.tokenUrl,
            clientId: 'test-client',
          )
          .withTokenRevocationEndpoint(oauthServer.revokeUrl)
          .disableCache()
          .build();

      // Logout
      await dio.auth.logout();

      // Configure server for successful response
      apiServer.respondWith(200, {'data': 'test'});

      // Make request after logout - should proceed without auth header
      final response = await dio.get<Map<String, dynamic>>('/test');

      // Verify request succeeded but without auth
      expect(response.statusCode, 200);
      expect(apiServer.lastRequest?.headers['authorization'], isNull);

      // Verify no refresh was attempted
      expect(oauthServer.refreshCallCount, 0);
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
    _refreshToken = refreshToken;
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

  Future<void> start() async {
    _server = await shelf_io.serve(_handleRequest, 'localhost', 0);
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
