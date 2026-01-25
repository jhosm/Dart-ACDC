import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_acdc/dart_acdc.dart';
import 'package:dio/dio.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import '../helpers/fake_oauth_server.dart';
import '../helpers/fake_token_provider.dart';
import '../helpers/mock_network_info.dart';

/// Integration test for a fully-configured ACDC client.
///
/// Tests the complete end-to-end flow with:
/// - Authentication with token refresh
/// - Error handling and exception mapping
/// - Custom interceptors working alongside built-in ones
/// - All interceptors in correct order
void main() {
  group('Complete Client Integration', () {
    late FakeOAuthServer oauthServer;
    late FakeApiServer apiServer;
    late FakeTokenProvider tokenProvider;

    setUp(() async {
      oauthServer = FakeOAuthServer();
      await oauthServer.start();

      apiServer = FakeApiServer();
      await apiServer.start();

      tokenProvider = FakeTokenProvider();

      // Reset servers for each test
      oauthServer.reset();
      apiServer.reset();
    });

    tearDown(() async {
      await oauthServer.stop();
      await apiServer.stop();
    });

    test('fully-configured client makes successful authenticated request',
        () async {
      // Configure token provider with valid token
      tokenProvider.setInitialState(
        accessToken: 'valid-access-token',
        refreshToken: 'valid-refresh-token',
      );

      // Build fully-configured client
      final dio = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTimeout(const Duration(seconds: 5))
          .withTokenProvider(tokenProvider)
          .withTokenRefreshEndpoint(
            url: oauthServer.tokenUrl,
            clientId: 'test-client',
          )
          .withTokenRevocationEndpoint(oauthServer.revokeUrl)
          .withLogLevel(LogLevel.debug)
          .withLogLevel(LogLevel.debug)
          .disableCache()
          .withNetworkInfo(MockNetworkInfo())
          .build();

      // Make authenticated request
      apiServer.respondWith(200, {'data': 'success'});
      final response = await dio.get<Map<String, dynamic>>('/users');

      // Verify request succeeded
      expect(response.statusCode, 200);
      expect(response.data, {'data': 'success'});

      // Verify auth token was sent
      expect(
        apiServer.lastRequest?.headers['authorization'],
        'Bearer valid-access-token',
      );
    });

    test('client proactively refreshes expiring token before request',
        () async {
      // Set token expiring in 30 seconds (within default 60s threshold)
      final expiry = DateTime.now().toUtc().add(const Duration(seconds: 30));
      tokenProvider.setInitialState(
        accessToken: 'expiring-token',
        refreshToken: 'valid-refresh-token',
        accessExpiry: expiry,
      );

      // Configure OAuth server to return new token
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

      // Make request - should trigger proactive refresh
      apiServer.respondWith(200, {'result': 'ok'});
      final response = await dio.get<Map<String, dynamic>>('/data');

      // Verify refresh was called
      expect(oauthServer.refreshCallCount, 1);

      // Verify new token was stored
      expect(await tokenProvider.getAccessToken(), 'refreshed-token');
      expect(await tokenProvider.getRefreshToken(), 'new-refresh-token');

      // Verify request used new token
      expect(response.statusCode, 200);
      expect(
        apiServer.lastRequest?.headers['authorization'],
        'Bearer refreshed-token',
      );
    });

    test('client reactively refreshes token on 401 response', () async {
      tokenProvider.setInitialState(
        accessToken: 'expired-token',
        refreshToken: 'valid-refresh-token',
      );

      oauthServer.respondWithSuccess();

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

      // First request returns 401, then 200 after refresh
      apiServer.respondWith401ThenSuccess({'data': 'protected'});

      final response = await dio.get<Map<String, dynamic>>('/protected');

      // Verify refresh happened
      expect(oauthServer.refreshCallCount, 1);

      // Verify retry succeeded with new token
      expect(response.statusCode, 200);
      expect(response.data, {'data': 'protected'});
      expect(await tokenProvider.getAccessToken(), 'new-access-token');
    });

    test('error interceptor converts HTTP errors to ACDC exceptions', () async {
      // Test 4xx client error
      apiServer
        ..reset()
        ..respondWith(400, {'error': 'Bad request'});
      final dio1 = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withTokenProvider(tokenProvider)
          .disableCache()
          .withNetworkInfo(MockNetworkInfo())
          .build();

      await expectLater(
        dio1.get<dynamic>('/bad-request'),
        throwsA(
          isA<AcdcClientException>().having(
            (e) => e.statusCode,
            'statusCode',
            400,
          ),
        ),
      );

      // Test 5xx server error
      apiServer
        ..reset()
        ..respondWith(500, {'error': 'Internal error'});
      final dio2 = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withTokenProvider(tokenProvider)
          .disableCache()
          .withNetworkInfo(MockNetworkInfo())
          .build();

      await expectLater(
        dio2.get<dynamic>('/server-error'),
        throwsA(
          isA<AcdcServerException>().having(
            (e) => e.statusCode,
            'statusCode',
            500,
          ),
        ),
      );

      // Test 401 auth error (without auth configured)
      apiServer
        ..reset()
        ..respondWith(401, {'error': 'Unauthorized'});
      final dio3 = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withTokenProvider(tokenProvider)
          .disableCache()
          .withNetworkInfo(MockNetworkInfo())
          .build();

      await expectLater(
        dio3.get<dynamic>('/unauthorized'),
        throwsA(
          isA<AcdcAuthException>().having(
            (e) => e.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });

    test('custom interceptor works alongside built-in interceptors', () async {
      var customInterceptorCalled = false;
      final customInterceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          customInterceptorCalled = true;
          options.headers['X-Custom-Header'] = 'custom-value';
          handler.next(options);
        },
      );

      tokenProvider.setInitialState(
        accessToken: 'test-token',
        refreshToken: 'test-refresh',
      );

      final dio = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withTokenRefreshEndpoint(
            url: oauthServer.tokenUrl,
            clientId: 'test-client',
          )
          .withInterceptor(customInterceptor)
          .withInterceptor(customInterceptor)
          .disableCache()
          .withNetworkInfo(MockNetworkInfo())
          .build();

      apiServer.respondWith(200, {'status': 'ok'});
      await dio.get<Map<String, dynamic>>('/test');

      // Verify custom interceptor was called
      expect(customInterceptorCalled, true);

      // Verify both auth and custom headers were added
      final request = apiServer.lastRequest!;
      expect(request.headers['authorization'], 'Bearer test-token');
      expect(request.headers['x-custom-header'], 'custom-value');
    });

    test('client handles concurrent requests during token refresh', () async {
      // Token expiring soon to trigger proactive refresh
      final expiry = DateTime.now().toUtc().add(const Duration(seconds: 30));
      tokenProvider.setInitialState(
        accessToken: 'expiring-token',
        refreshToken: 'valid-refresh-token',
        accessExpiry: expiry,
      );

      // Add delay to refresh to ensure concurrent requests queue
      oauthServer
        ..responseDelay = const Duration(milliseconds: 100)
        ..respondWithSuccess(
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

      // Make 3 concurrent requests
      final futures = [
        dio.get<Map<String, dynamic>>('/data1'),
        dio.get<Map<String, dynamic>>('/data2'),
        dio.get<Map<String, dynamic>>('/data3'),
      ];

      final responses = await Future.wait(futures);

      // Verify all requests succeeded
      expect(responses.length, 3);
      for (final response in responses) {
        expect(response.statusCode, 200);
      }

      // Verify refresh was called only once (queuing worked)
      expect(oauthServer.refreshCallCount, 1);

      // Verify all requests used refreshed token
      expect(await tokenProvider.getAccessToken(), 'refreshed-token');
    });

    test('auth manager logout revokes tokens and clears storage', () async {
      tokenProvider.setInitialState(
        accessToken: 'active-token',
        refreshToken: 'active-refresh',
      );

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

      // Logout
      await dio.auth.logout();

      // Verify revocation was called
      expect(oauthServer.revokeCallCount, 2); // Once for each token

      // Verify tokens were cleared
      expect(await tokenProvider.getAccessToken(), isNull);
      expect(await tokenProvider.getRefreshToken(), isNull);
    });

    test('network errors are converted to AcdcNetworkException', () async {
      final dio = await const AcdcClientBuilder()
          .withBaseUrl('http://invalid-host-that-does-not-exist.test')
          .withTokenProvider(tokenProvider)
          .withTimeout(const Duration(milliseconds: 100))
          .withTimeout(const Duration(milliseconds: 100))
          .disableCache()
          .withNetworkInfo(MockNetworkInfo())
          .build();

      expect(
        () => dio.get<dynamic>('/test'),
        throwsA(isA<AcdcNetworkException>()),
      );
    });
  });
}

/// Fake API server for testing.
class FakeApiServer {
  HttpServer? _server;
  int? _port;
  shelf.Request? lastRequest;

  int _responseStatusCode = 200;
  Map<String, dynamic> _responseData = {};
  bool _return401First = false;
  int _requestCount = 0;

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
    _return401First = false;
    _requestCount = 0;
    lastRequest = null;
  }

  void respondWith(int statusCode, Map<String, dynamic> data) {
    _responseStatusCode = statusCode;
    _responseData = data;
    _return401First = false;
    _requestCount = 0;
  }

  void respondWith401ThenSuccess(Map<String, dynamic> successData) {
    _return401First = true;
    _responseData = successData;
    _responseStatusCode = 200;
    _requestCount = 0;
  }

  Future<shelf.Response> _handleRequest(shelf.Request request) async {
    lastRequest = request;

    // Handle 401 then success scenario
    if (_return401First) {
      _requestCount++;
      if (_requestCount == 1) {
        return shelf.Response(
          401,
          body: jsonEncode({'error': 'Unauthorized'}),
          headers: {'content-type': 'application/json'},
        );
      }
    }

    return shelf.Response(
      _responseStatusCode,
      body: jsonEncode(_responseData),
      headers: {'content-type': 'application/json'},
    );
  }
}
