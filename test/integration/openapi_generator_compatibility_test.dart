import 'dart:convert';
import 'dart:io';

import 'package:dart_acdc/dart_acdc.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/openapi.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../helpers/fake_oauth_server.dart';

/// Integration test verifying ACDC-configured Dio instances work seamlessly
/// with OpenAPI-generated clients.
///
/// This test ensures that the Dio instance returned by AcdcClientBuilder is
/// a standard Dio instance (not a wrapper) that maintains full ecosystem
/// compatibility with code generation tools like openapi-generator.
void main() {
// TestWidgetsFlutterBinding.ensureInitialized();

  group('OpenAPI Generator Compatibility', () {
    late FakeOAuthServer oauthServer;
    late FakeGitHubApiServer apiServer;
    late TestTokenProvider tokenProvider;

    setUp(() async {
      oauthServer = FakeOAuthServer();
      await oauthServer.start();

      apiServer = FakeGitHubApiServer();
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

    test('ACDC Dio instance is compatible with openapi-generated client',
        () async {
      // Scenario: Configure a Dio instance with ACDC builder and pass it to
      // an openapi-generated client constructor.
      // Expected: The client accepts it without modification or errors.

      // Configure token provider
      tokenProvider.initializeTokens(
        accessToken: 'valid-token',
        refreshToken: 'valid-refresh',
      );

      // Build ACDC-configured Dio instance
      final dio = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTimeout(const Duration(seconds: 5))
          .withTokenProvider(tokenProvider)
          .withTokenRefreshEndpoint(
            url: oauthServer.tokenUrl,
            clientId: 'test-client',
          )
          .withLogLevel(LogLevel.info)
          .disableCache()
          .build();

      // Pass to openapi-generated client - this should work without errors
      final apiClient = Openapi(
        dio: dio,
        basePathOverride: apiServer.baseUrl,
      );

      // Verify client was created successfully
      expect(apiClient, isNotNull);
      expect(apiClient.dio, same(dio));
    });

    test(
        'openapi-generated client makes successful API call with ACDC interceptors',
        () async {
      // Scenario: Make an API call through the openapi-generated client
      // using an ACDC-configured Dio instance.
      // Expected: Request succeeds and all ACDC interceptors function correctly
      // (auth, error handling, logging).

      tokenProvider.initializeTokens(
        accessToken: 'api-token',
        refreshToken: 'api-refresh',
      );

      final dio = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withTokenRefreshEndpoint(
            url: oauthServer.tokenUrl,
            clientId: 'test-client',
          )
          .withLogLevel(LogLevel.debug)
          .disableCache()
          .build();

      final apiClient = Openapi(
        dio: dio,
        basePathOverride: apiServer.baseUrl,
      );

      // Configure fake server to return repos data
      apiServer.respondWithRepos([
        {'id': 1, 'name': 'repo-1', 'full_name': 'user/repo-1'},
        {'id': 2, 'name': 'repo-2', 'full_name': 'user/repo-2'},
      ]);

      // Make API call through generated client
      final api = apiClient.getDefaultApi();
      final response = await api.listRepos();

      // Verify successful response
      expect(response.statusCode, 200);
      expect(response.data, isNotNull);
      expect(response.data!.length, 2);
      expect(response.data![0].id, 1);
      expect(response.data![0].name, 'repo-1');
      expect(response.data![1].id, 2);

      // Verify ACDC auth interceptor added Bearer token
      expect(
        apiServer.lastRequest?.headers['authorization'],
        'Bearer api-token',
      );
    });

    test('openapi-generated client handles token refresh transparently',
        () async {
      // Scenario: Make API call when token is expiring.
      // Expected: ACDC auth interceptor refreshes token proactively,
      // and openapi-generated client uses the new token seamlessly.

      // Set token expiring in 30 seconds (within default 60s threshold)
      final expiry = DateTime.now().toUtc().add(const Duration(seconds: 30));
      tokenProvider.initializeTokens(
        accessToken: 'expiring-token',
        refreshToken: 'valid-refresh',
        accessExpiry: expiry,
      );

      // Configure OAuth server for refresh
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
          .build();

      final apiClient = Openapi(
        dio: dio,
        basePathOverride: apiServer.baseUrl,
      );

      apiServer.respondWithRepos([
        {'id': 3, 'name': 'new-repo', 'full_name': 'user/new-repo'},
      ]);

      // Make API call - should trigger proactive refresh
      final api = apiClient.getDefaultApi();
      final response = await api.listRepos();

      // Verify refresh was triggered
      expect(oauthServer.refreshCallCount, 1);

      // Verify new token was used
      expect(await tokenProvider.getAccessToken(), 'refreshed-token');
      expect(
        apiServer.lastRequest?.headers['authorization'],
        'Bearer refreshed-token',
      );

      // Verify API call succeeded
      expect(response.statusCode, 200);
      expect(response.data![0].name, 'new-repo');
    });

    test('openapi-generated client handles 401 with reactive token refresh',
        () async {
      // Scenario: API returns 401, triggering reactive token refresh.
      // Expected: ACDC auth interceptor refreshes token and retries,
      // openapi-generated client receives successful response.

      tokenProvider.initializeTokens(
        accessToken: 'expired-token',
        refreshToken: 'valid-refresh',
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
          .build();

      final apiClient = Openapi(
        dio: dio,
        basePathOverride: apiServer.baseUrl,
      );

      // First request returns 401, second succeeds
      apiServer.respondWith401ThenRepos([
        {'id': 4, 'name': 'protected-repo', 'full_name': 'user/protected-repo'},
      ]);

      final api = apiClient.getDefaultApi();
      final response = await api.listRepos();

      // Verify refresh happened
      expect(oauthServer.refreshCallCount, 1);

      // Verify retry succeeded
      expect(response.statusCode, 200);
      expect(response.data![0].name, 'protected-repo');
      expect(await tokenProvider.getAccessToken(), 'new-access-token');
    });

    test('openapi-generated client receives ACDC exceptions on errors',
        () async {
      // Scenario: API returns 4xx/5xx errors.
      // Expected: ACDC error interceptor converts to AcdcException types,
      // which propagate through openapi-generated client.

      final dio = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(TestTokenProvider())
          .disableCache()
          .build();

      final apiClient = Openapi(
        dio: dio,
        basePathOverride: apiServer.baseUrl,
      );

      final api = apiClient.getDefaultApi();

      // Test 404 error
      apiServer.respondWith(404, {'error': 'Not found'});
      await expectLater(
        api.listRepos(),
        throwsA(
          isA<AcdcClientException>()
              .having((e) => e.statusCode, 'statusCode', 404),
        ),
      );

      // Test 500 error
      apiServer
        ..reset()
        ..respondWith(500, {'error': 'Server error'});
      await expectLater(
        api.listRepos(),
        throwsA(
          isA<AcdcServerException>()
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });

    test('openapi-generated client works with custom ACDC interceptors',
        () async {
      // Scenario: Add custom interceptor alongside ACDC interceptors.
      // Expected: All interceptors work together, including custom ones.

      var customHeaderAdded = false;
      final customInterceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          customHeaderAdded = true;
          options.headers['X-Custom-Header'] = 'custom-value';
          handler.next(options);
        },
      );

      tokenProvider.initializeTokens(
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
          .disableCache()
          .build();

      final apiClient = Openapi(
        dio: dio,
        basePathOverride: apiServer.baseUrl,
      );

      apiServer.respondWithRepos([
        {'id': 5, 'name': 'custom-repo', 'full_name': 'user/custom-repo'},
      ]);

      final api = apiClient.getDefaultApi();
      await api.listRepos();

      // Verify custom interceptor was called
      expect(customHeaderAdded, true);

      // Verify both custom and auth headers were added
      expect(apiServer.lastRequest?.headers['x-custom-header'], 'custom-value');
      expect(
        apiServer.lastRequest?.headers['authorization'],
        'Bearer test-token',
      );
    });

    test('openapi-generated client works with getAuthenticatedUser endpoint',
        () async {
      // Scenario: Test a different endpoint (Return a single object).
      // Expected: ACDC Dio works correctly with various endpoint types.

      tokenProvider.initializeTokens(
        accessToken: 'user-token',
        refreshToken: 'user-refresh',
      );

      final dio = await const AcdcClientBuilder()
          .withBaseUrl(apiServer.baseUrl)
          .withTokenProvider(tokenProvider)
          .withTokenRefreshEndpoint(
            url: oauthServer.tokenUrl,
            clientId: 'test-client',
          )
          .disableCache()
          .build();

      final apiClient = Openapi(
        dio: dio,
        basePathOverride: apiServer.baseUrl,
      );

      apiServer.respondWithUser({
        'id': 100,
        'login': 'test-user',
        'email': 'test@example.com',
        'name': 'Test User',
      });

      final api = apiClient.getDefaultApi();
      final response = await api.getAuthenticatedUser();

      expect(response.statusCode, 200);
      expect(response.data, isNotNull);
      expect(response.data!.id, 100);
      expect(response.data!.login, 'test-user');
      expect(response.data!.email, 'test@example.com');
    });
  });
}

/// Test implementation of TokenProvider.
class TestTokenProvider implements TokenProvider {
  String? _accessToken;
  String? _refreshToken;
  DateTime? _accessExpiry;
  DateTime? _refreshExpiry;

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

/// Fake API server for testing GitHub API endpoints.
class FakeGitHubApiServer {
  HttpServer? _server;
  int? _port;
  shelf.Request? lastRequest;

  int _responseStatusCode = 200;
  dynamic _responseData;
  bool _return401First = false;
  int _requestCount = 0;

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
    _responseData = null;
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

  void respondWithRepos(List<Map<String, dynamic>> repos) {
    _responseStatusCode = 200;
    _responseData = repos;
    _return401First = false;
    _requestCount = 0;
  }

  void respondWithUser(Map<String, dynamic> user) {
    _responseStatusCode = 200;
    _responseData = user;
    _return401First = false;
    _requestCount = 0;
  }

  void respondWith401ThenRepos(List<Map<String, dynamic>> repos) {
    _return401First = true;
    _responseData = repos;
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

    // Check path for basic validation (optional, but good for sanity)
    if (request.url.path == 'user/repos' ||
        request.url.path == 'user' ||
        request.url.path == 'user/') {
      // All good
    }

    return shelf.Response(
      _responseStatusCode,
      body: jsonEncode(_responseData),
      headers: {'content-type': 'application/json'},
    );
  }
}
