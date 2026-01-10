import 'package:dart_acdc/dart_acdc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_oauth_server.dart';
import '../helpers/mock_network_info.dart';

/// Integration tests for OAuth 2.1 compliance.
///
/// Tests that verify the library follows OAuth 2.1 specification for:
/// - Token refresh request format
/// - Required parameters
/// - Content type headers
/// - Client authentication (public client pattern for mobile apps)
void main() {
  // TestWidgetsFlutterBinding.ensureInitialized(); // Not needed with cache disabled

  group('OAuth 2.1 Compliance', () {
    late FakeOAuthServer oauthServer;
    late TestTokenProvider tokenProvider;

    setUp(() async {
      oauthServer = FakeOAuthServer();
      await oauthServer.start();

      tokenProvider = TestTokenProvider();

      // Reset server for each test
      oauthServer.reset();
    });

    tearDown(() async {
      await oauthServer.stop();
    });

    test('refresh request uses correct format and parameters', () async {
      const clientId = 'test-client-id';
      const testRefreshToken = 'test-refresh-token';

      // Configure server to return success
      oauthServer.respondWithSuccess();

      // Set up token provider with expiring token to trigger refresh
      final expiry = DateTime.now().toUtc().add(const Duration(seconds: 30));
      tokenProvider.initializeTokens(
        accessToken: 'expiring-token',
        refreshToken: testRefreshToken,
        accessExpiry: expiry,
      );

      // Build client with OAuth token refresh endpoint
      final dio = await const AcdcClientBuilder()
          .withBaseUrl('http://localhost:9999')
          .withTokenProvider(tokenProvider)
          .withNetworkInfo(MockNetworkInfo())
          .withTokenRefreshEndpoint(
            url: oauthServer.tokenUrl,
            clientId: clientId,
          )
          .disableCache()
          .build();

      // Trigger a proactive refresh by making a request
      // (We don't need actual API server since refresh happens first)
      try {
        await dio.get<void>('/test');
      } on Exception {
        // Ignore connection errors - we only care about the OAuth request
      }

      // Verify OAuth server received exactly one refresh request
      expect(oauthServer.refreshCallCount, 1);
      expect(oauthServer.receivedRequests.length, 1);

      final request = oauthServer.receivedRequests.first;

      // Verify HTTP method
      expect(request.method, 'POST', reason: 'Refresh must use POST method');

      // Verify endpoint
      expect(
        request.url.path,
        'token',
        reason: 'Request must be to /token endpoint',
      );

      // Verify Content-Type header
      expect(
        request.headers['content-type'],
        contains('application/x-www-form-urlencoded'),
        reason: 'Content-Type must be application/x-www-form-urlencoded',
      );

      // Get parsed parameters from server
      final params = oauthServer.lastRefreshRequestParams!;

      // Verify required parameters are present
      expect(
        params['grant_type'],
        'refresh_token',
        reason: 'grant_type parameter must be "refresh_token"',
      );

      expect(
        params['refresh_token'],
        testRefreshToken,
        reason: 'refresh_token parameter must be the refresh token',
      );

      expect(
        params['client_id'],
        clientId,
        reason: 'client_id parameter must be the configured client ID',
      );

      // Verify client_secret is NOT included (public client pattern)
      expect(
        params.containsKey('client_secret'),
        isFalse,
        reason:
            'client_secret must NOT be included (mobile apps are public clients)',
      );

      // Verify only expected parameters are present (no extra fields)
      expect(
        params.keys.toSet(),
        {'grant_type', 'refresh_token', 'client_id'},
        reason: 'Request should only include required OAuth 2.1 parameters',
      );
    });

    test('refresh request includes Accept: application/json header', () async {
      const clientId = 'test-client-id';

      oauthServer.respondWithSuccess();

      final expiry = DateTime.now().toUtc().add(const Duration(seconds: 30));
      tokenProvider.initializeTokens(
        accessToken: 'expiring-token',
        refreshToken: 'test-refresh-token',
        accessExpiry: expiry,
      );

      final dio = await const AcdcClientBuilder()
          .withBaseUrl('http://localhost:9999')
          .withTokenProvider(tokenProvider)
          .withNetworkInfo(MockNetworkInfo())
          .withTokenRefreshEndpoint(
            url: oauthServer.tokenUrl,
            clientId: clientId,
          )
          .disableCache()
          .build();

      try {
        await dio.get<void>('/test');
      } on Exception {
        // Ignore connection errors
      }

      expect(oauthServer.refreshCallCount, 1);

      final request = oauthServer.receivedRequests.first;

      // Verify Accept header
      expect(
        request.headers['accept'],
        contains('application/json'),
        reason: 'Accept header should indicate JSON response expected',
      );
    });

    test('refresh request handles token rotation correctly', () async {
      const clientId = 'test-client-id';
      const originalRefreshToken = 'original-refresh-token';
      const rotatedRefreshToken = 'rotated-refresh-token';

      // Configure server to return rotated refresh token
      oauthServer.respondWithSuccess(
        refreshToken: rotatedRefreshToken,
      );

      final expiry = DateTime.now().toUtc().add(const Duration(seconds: 30));
      tokenProvider.initializeTokens(
        accessToken: 'expiring-token',
        refreshToken: originalRefreshToken,
        accessExpiry: expiry,
      );

      final dio = await const AcdcClientBuilder()
          .withBaseUrl('http://localhost:9999')
          .withTokenProvider(tokenProvider)
          .withNetworkInfo(MockNetworkInfo())
          .withTokenRefreshEndpoint(
            url: oauthServer.tokenUrl,
            clientId: clientId,
          )
          .disableCache()
          .build();

      try {
        await dio.get<void>('/test');
      } on Exception {
        // Ignore connection errors
      }

      // Verify the rotated refresh token was stored
      expect(
        await tokenProvider.getRefreshToken(),
        rotatedRefreshToken,
        reason: 'Token provider should store the rotated refresh token',
      );
    });

    test(
        'refresh request does not include refresh_token when response omits it',
        () async {
      const clientId = 'test-client-id';
      const originalRefreshToken = 'original-refresh-token';

      // Configure server to NOT return a new refresh token
      oauthServer.respondWithSuccess(
        refreshToken: null, // No token rotation
      );

      final expiry = DateTime.now().toUtc().add(const Duration(seconds: 30));
      tokenProvider.initializeTokens(
        accessToken: 'expiring-token',
        refreshToken: originalRefreshToken,
        accessExpiry: expiry,
      );

      final dio = await const AcdcClientBuilder()
          .withBaseUrl('http://localhost:9999')
          .withTokenProvider(tokenProvider)
          .withNetworkInfo(MockNetworkInfo())
          .withTokenRefreshEndpoint(
            url: oauthServer.tokenUrl,
            clientId: clientId,
          )
          .disableCache()
          .build();

      try {
        await dio.get<void>('/test');
      } on Exception {
        // Ignore connection errors
      }

      // Verify the original refresh token is preserved when rotation doesn't occur
      expect(
        await tokenProvider.getRefreshToken(),
        originalRefreshToken,
        reason:
            'Token provider should keep original refresh token when not rotated',
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
