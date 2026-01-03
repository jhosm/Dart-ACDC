import 'dart:convert';
import 'dart:io';

import 'package:dart_acdc/dart_acdc.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Integration test for custom token refresh function.
///
/// Tests that a custom refresh function provided via withCustomTokenRefresh():
/// - Is actually called during token refresh
/// - Receives the refresh token as a parameter
/// - Its returned TokenRefreshResult is used to update tokens
/// - Works for both proactive and reactive refresh scenarios
void main() {
// TestWidgetsFlutterBinding.ensureInitialized();

  group('Custom Token Refresh Function', () {
    late FakeApiServer apiServer;
    late TestTokenProvider tokenProvider;

    setUp(() async {
      apiServer = FakeApiServer();
      await apiServer.start();

      tokenProvider = TestTokenProvider();

      // Reset server for each test
      apiServer.reset();
    });

    tearDown(() async {
      await apiServer.stop();
    });

    test('custom refresh function is called during proactive token refresh',
        () async {
      // Track custom function invocations
      final invocations = <String>[];

      Future<TokenRefreshResult> customRefresh(String refreshToken) async {
        invocations.add(refreshToken);
        return const TokenRefreshResult(
          accessToken: 'custom-refreshed-access-token',
          refreshToken: 'custom-refreshed-refresh-token',
        );
      }

      // Set token expiring soon to trigger proactive refresh
      final expiry = DateTime.now().toUtc().add(const Duration(seconds: 30));
      tokenProvider.initializeTokens(
        accessToken: 'expiring-token',
        refreshToken: 'original-refresh-token',
        accessExpiry: expiry,
      );

      final dio = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withCustomTokenRefresh(customRefresh)
          .disableCache()
          .build();

      apiServer.respondWith(200, {'result': 'success'});

      // Make request - should trigger proactive refresh
      final response = await dio.get<Map<String, dynamic>>('/data');

      expect(response.statusCode, 200);

      // Verify custom function was called with correct refresh token
      expect(invocations.length, 1);
      expect(invocations[0], 'original-refresh-token');

      // Verify tokens were updated with custom function's result
      expect(
        await tokenProvider.getAccessToken(),
        'custom-refreshed-access-token',
      );
      expect(
        await tokenProvider.getRefreshToken(),
        'custom-refreshed-refresh-token',
      );

      // Verify the refreshed token was used in the request
      expect(
        apiServer.lastRequest?.headers['authorization'],
        'Bearer custom-refreshed-access-token',
      );
    });

    test(
        'custom refresh function is called during reactive token refresh (401)',
        () async {
      // Track custom function invocations
      final invocations = <String>[];

      Future<TokenRefreshResult> customRefresh(String refreshToken) async {
        invocations.add(refreshToken);
        return const TokenRefreshResult(
          accessToken: 'new-access-after-401',
          refreshToken: 'new-refresh-after-401',
        );
      }

      tokenProvider.initializeTokens(
        accessToken: 'invalid-token',
        refreshToken: 'valid-refresh-token',
      );

      final dio = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withCustomTokenRefresh(customRefresh)
          .disableCache()
          .build();

      // Configure server to respond with 401 first, then success on retry
      var requestCount = 0;
      apiServer.dynamicHandler = (request) {
        requestCount++;
        if (requestCount == 1) {
          return (401, {'error': 'unauthorized'});
        } else {
          return (200, {'result': 'success'});
        }
      };

      // Make request - should get 401, trigger refresh, retry
      final response = await dio.get<Map<String, dynamic>>('/protected');

      expect(response.statusCode, 200);

      // Verify custom function was called with correct refresh token
      expect(invocations.length, 1);
      expect(invocations[0], 'valid-refresh-token');

      // Verify tokens were updated
      expect(await tokenProvider.getAccessToken(), 'new-access-after-401');
      expect(await tokenProvider.getRefreshToken(), 'new-refresh-after-401');
    });

    test('custom refresh function receives correct refresh token parameter',
        () async {
      String? receivedToken;

      Future<TokenRefreshResult> customRefresh(String refreshToken) async {
        receivedToken = refreshToken;
        return const TokenRefreshResult(
          accessToken: 'new-access',
          refreshToken: 'new-refresh',
        );
      }

      // Use a specific refresh token to verify it's passed correctly
      const testRefreshToken = 'my-specific-refresh-token-12345';
      final expiry = DateTime.now().toUtc().add(const Duration(seconds: 30));
      tokenProvider.initializeTokens(
        accessToken: 'expiring-token',
        refreshToken: testRefreshToken,
        accessExpiry: expiry,
      );

      final dio = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withCustomTokenRefresh(customRefresh)
          .disableCache()
          .build();

      apiServer.respondWith(200, {'data': 'test'});

      await dio.get<Map<String, dynamic>>('/test');

      // Verify the exact refresh token was passed to custom function
      expect(receivedToken, testRefreshToken);
    });

    test('custom refresh function result updates all token fields', () async {
      final now = DateTime.now().toUtc();
      final newAccessExpiry = now.add(const Duration(hours: 1));
      final newRefreshExpiry = now.add(const Duration(days: 30));

      Future<TokenRefreshResult> customRefresh(String refreshToken) async =>
          TokenRefreshResult(
            accessToken: 'full-result-access',
            refreshToken: 'full-result-refresh',
            accessExpiry: newAccessExpiry,
            refreshExpiry: newRefreshExpiry,
          );

      final expiry = now.add(const Duration(seconds: 30));
      tokenProvider.initializeTokens(
        accessToken: 'old-token',
        refreshToken: 'old-refresh',
        accessExpiry: expiry,
      );

      final dio = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withCustomTokenRefresh(customRefresh)
          .disableCache()
          .build();

      apiServer.respondWith(200, {'data': 'test'});

      await dio.get<Map<String, dynamic>>('/test');

      // Verify all token fields were updated
      expect(await tokenProvider.getAccessToken(), 'full-result-access');
      expect(await tokenProvider.getRefreshToken(), 'full-result-refresh');
      expect(await tokenProvider.getAccessTokenExpiry(), newAccessExpiry);
      expect(await tokenProvider.getRefreshTokenExpiry(), newRefreshExpiry);
    });

    test('custom refresh function is called only once for concurrent requests',
        () async {
      var callCount = 0;

      Future<TokenRefreshResult> customRefresh(String refreshToken) async {
        callCount++;
        // Add delay to simulate network request
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return const TokenRefreshResult(
          accessToken: 'concurrent-access',
          refreshToken: 'concurrent-refresh',
        );
      }

      final expiry = DateTime.now().toUtc().add(const Duration(seconds: 30));
      tokenProvider.initializeTokens(
        accessToken: 'expiring-token',
        refreshToken: 'refresh-token',
        accessExpiry: expiry,
      );

      final dio = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withCustomTokenRefresh(customRefresh)
          .disableCache()
          .build();

      apiServer.respondWith(200, {'data': 'test'});

      // Start multiple concurrent requests
      final futures = [
        dio.get<Map<String, dynamic>>('/req1'),
        dio.get<Map<String, dynamic>>('/req2'),
        dio.get<Map<String, dynamic>>('/req3'),
      ];

      await Future.wait(futures);

      // Verify custom function was called only once (not 3 times)
      expect(callCount, 1);
    });

    test('custom refresh function exception clears tokens', () async {
      Future<TokenRefreshResult> customRefresh(String refreshToken) async {
        throw AcdcAuthException(
          requestOptions: RequestOptions(path: '/'),
          message: 'Custom refresh failed',
        );
      }

      // Use valid token initially to avoid proactive refresh
      tokenProvider.initializeTokens(
        accessToken: 'invalid-token',
        refreshToken: 'refresh-token',
      );

      final dio = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withCustomTokenRefresh(customRefresh)
          .disableCache()
          .build();

      // Server returns 401 to trigger reactive refresh
      apiServer.respondWith(401, {'error': 'unauthorized'});

      // Request should fail due to refresh failure
      await expectLater(
        dio.get<Map<String, dynamic>>('/test'),
        throwsA(isA<AcdcAuthException>()),
      );

      // Verify tokens were cleared
      expect(await tokenProvider.getAccessToken(), isNull);
      expect(await tokenProvider.getRefreshToken(), isNull);
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

  // ignore: avoid_setters_without_getters
  set dynamicHandler(
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
