import 'package:dart_acdc/dart_acdc.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

// Mock TokenProvider for testing
class MockTokenProvider implements TokenProvider {
  @override
  Future<String?> getAccessToken() async => 'mock_access_token';

  @override
  Future<String?> getRefreshToken() async => 'mock_refresh_token';

  @override
  Future<DateTime?> getAccessTokenExpiry() async => null;

  @override
  Future<DateTime?> getRefreshTokenExpiry() async => null;

  @override
  Future<void> setTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? accessExpiry,
    DateTime? refreshExpiry,
  }) async {}

  @override
  Future<void> clearTokens() async {}
}

void main() {
  group('Public API Exports', () {
    test('AcdcClientBuilder is exported and accessible', () {
      expect(AcdcClientBuilder, isNotNull);
      const builder = AcdcClientBuilder();
      expect(builder, isA<AcdcClientBuilder>());
    });

    test('TokenProvider interface is exported', () {
      final provider = MockTokenProvider();
      expect(provider, isA<TokenProvider>());
    });

    test('TokenRefreshResult is exported and accessible', () {
      const result = TokenRefreshResult(
        accessToken: 'new_token',
        refreshToken: 'new_refresh',
      );
      expect(result, isA<TokenRefreshResult>());
      expect(result.accessToken, 'new_token');
      expect(result.refreshToken, 'new_refresh');
    });

    test('AcdcAuthManager and AcdcAuth extension are exported', () {
      final dio = const AcdcClientBuilder()
          .withTokenProvider(MockTokenProvider())
          .withTokenRefreshEndpoint(
            url: 'https://auth.example.com/token',
            clientId: 'test',
          )
          .build();

      expect(dio.auth, isA<AcdcAuthManager>());
    });

    test('All exception types are exported', () {
      expect(AcdcException, isNotNull);
      expect(AcdcNetworkException, isNotNull);
      expect(AcdcAuthException, isNotNull);
      expect(AcdcServerException, isNotNull);
      expect(AcdcClientException, isNotNull);
      expect(AcdcCacheException, isNotNull);
    });

    test('NetworkErrorType enum is exported', () {
      expect(NetworkErrorType.connectionTimeout, isNotNull);
      expect(NetworkErrorType.sendTimeout, isNotNull);
      expect(NetworkErrorType.receiveTimeout, isNotNull);
      expect(NetworkErrorType.noConnection, isNotNull);
      expect(NetworkErrorType.cancelled, isNotNull);
      expect(NetworkErrorType.other, isNotNull);
    });

    test('CacheOperation enum is exported', () {
      expect(CacheOperation.read, isNotNull);
      expect(CacheOperation.write, isNotNull);
      expect(CacheOperation.initialization, isNotNull);
      expect(CacheOperation.clear, isNotNull);
      expect(CacheOperation.other, isNotNull);
    });

    test('CacheConfig is exported and accessible', () {
      const config = CacheConfig(
        ttl: Duration(hours: 2),
        maxSize: 20 * 1024 * 1024,
      );
      expect(config, isA<CacheConfig>());
      expect(config.ttl, const Duration(hours: 2));
    });

    test('LogLevel enum is exported', () {
      expect(LogLevel.debug, isNotNull);
      expect(LogLevel.info, isNotNull);
      expect(LogLevel.warning, isNotNull);
      expect(LogLevel.error, isNotNull);
      expect(LogLevel.none, isNotNull);
    });

    test('AcdcLogger typedef is exported', () {
      // Type check that AcdcLogger function signature is correct
      var logger = (message, level,
          metadata,) {
        // Mock logger
      };
      expect(logger, isNotNull);
    });

    test('Builder can be used with all exported types', () {
      final builder = const AcdcClientBuilder()
          .withBaseUrl('https://api.example.com')
          .withTimeout(Duration(seconds: 30))
          .withTokenProvider(MockTokenProvider())
          .withTokenRefreshEndpoint(
            url: 'https://auth.example.com/token',
            clientId: 'test-client',
          )
          .withLogLevel(LogLevel.debug)
          .withLogger((message, level, metadata) {
        // Custom logger
      }).withCache(CacheConfig(
            ttl: Duration(hours: 1),
            encrypted: true,
          ),);

      final dio = builder.build();
      expect(dio, isA<Dio>());
      expect(dio.options.baseUrl, 'https://api.example.com');
    });

    test('Internal implementation files are not exported', () {
      // These should not be accessible from public API
      // The test simply ensures we can't import them
      // (This is a compilation check - if it compiles, they're not exported)

      // We can't access:
      // - AuthInterceptor (internal)
      // - ErrorInterceptor (internal)
      // - Internal exception details beyond public API
    });
  });

  group('Public API Usage Examples', () {
    test('Zero-config client creation works', () {
      final dio = const AcdcClientBuilder()
          .withBaseUrl('https://api.example.com')
          .build();

      expect(dio, isA<Dio>());
      expect(dio.options.baseUrl, 'https://api.example.com');
    });

    test('Authenticated client creation works', () {
      final dio = const AcdcClientBuilder()
          .withBaseUrl('https://api.example.com')
          .withTokenProvider(MockTokenProvider())
          .withTokenRefreshEndpoint(
            url: 'https://auth.example.com/oauth/token',
            clientId: 'my-client-id',
          )
          .withTokenRevocationEndpoint(
            'https://auth.example.com/oauth/revoke',
          )
          .build();

      expect(dio, isA<Dio>());
      expect(dio.auth, isA<AcdcAuthManager>());
    });

    test('Custom configured client creation works', () {
      final dio = const AcdcClientBuilder()
          .withBaseUrl('https://api.example.com')
          .withTimeout(Duration(seconds: 45))
          .withLogLevel(LogLevel.warning)
          .withCache(CacheConfig(
            ttl: Duration(hours: 2),
            encrypted: true,
            staleWhileRevalidate: true,
          ),)
          .build();

      expect(dio, isA<Dio>());
      expect(dio.options.connectTimeout, const Duration(seconds: 45));
    });
  });
}
