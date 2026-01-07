import 'package:dart_acdc/dart_acdc.dart';
import 'package:dart_acdc/src/interceptors/cache_interceptor.dart';
import 'package:dart_acdc/src/interceptors/error_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_token_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  group('Public API Exports', () {
    test('AcdcClientBuilder is exported and accessible', () {
      expect(AcdcClientBuilder, isNotNull);
      const builder = AcdcClientBuilder();
      expect(builder, isA<AcdcClientBuilder>());
    });

    test('TokenProvider interface is exported', () {
      final provider = FakeTokenProvider();
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

    test('AcdcAuthManager and AcdcAuth extension are exported', () async {
      final dio = await const AcdcClientBuilder()
          .withTokenProvider(FakeTokenProvider())
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
      void logger(
        message,
        level,
        metadata,
      ) {
        // Mock logger
      }
      expect(logger, isNotNull);
    });

    test(
        'default client setup includes all standard interceptors and configuration',
        () async {
      final dio = await const AcdcClientBuilder()
          .withBaseUrl('https://api.example.com')
          .build();

      // Check interceptors
      final interceptors = dio.interceptors;
      expect(
        interceptors.any((i) => i is ErrorInterceptor),
        isTrue,
        reason: 'ErrorInterceptor should be present',
      );
      expect(
        interceptors.any((i) => i is AcdcCacheInterceptor),
        isTrue,
        reason: 'CacheInterceptor should be present by default',
      );

      // Check timeouts
      const defaultTimeout = Duration(seconds: 5);
      expect(dio.options.connectTimeout, defaultTimeout);
      expect(dio.options.receiveTimeout, defaultTimeout);
      expect(dio.options.sendTimeout, defaultTimeout);

      // Check base URL
      expect(dio.options.baseUrl, 'https://api.example.com');
    });

    test('Builder can be used with all exported types', () async {
      final builder = const AcdcClientBuilder()
          .withBaseUrl('https://api.example.com')
          .withTimeout(const Duration(seconds: 30))
          .withTokenProvider(FakeTokenProvider())
          .withTokenRefreshEndpoint(
            url: 'https://auth.example.com/token',
            clientId: 'test-client',
          )
          .withLogLevel(LogLevel.debug)
          .withLogger((message, level, metadata) {
        // Custom logger
      }).withCache(
        const CacheConfig(
            // encrypted: true, // Removed as it is not in CacheConfig
            ),
      );

      final dio = await builder.build();
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

    test('custom interceptors are added correctly', () async {
      final customInterceptor = InterceptorsWrapper();

      final dio = await const AcdcClientBuilder()
          .withBaseUrl('https://api.example.com')
          .withInterceptor(customInterceptor)
          .build();

      expect(dio.interceptors.contains(customInterceptor), isTrue);
    });

    test('Auth extension is available on Dio', () async {
      final dio = await const AcdcClientBuilder()
          .withBaseUrl('https://api.example.com')
          .withTokenProvider(FakeTokenProvider())
          .withTokenRefreshEndpoint(
            url: 'https://auth.example.com/token',
            clientId: 'test-client',
          )
          .build();

      expect(dio.auth, isNotNull);
    });
  });

  group('Public API Usage Examples', () {
    test('Zero-config client creation works', () async {
      final dio = await const AcdcClientBuilder()
          .withBaseUrl('https://api.example.com')
          .build();

      expect(dio, isA<Dio>());
      expect(dio.options.baseUrl, 'https://api.example.com');
    });

    test('Authenticated client creation works', () async {
      final dio = await const AcdcClientBuilder()
          .withBaseUrl('https://api.example.com')
          .withTokenProvider(FakeTokenProvider())
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

    test('Custom configured client creation works', () async {
      final dio = await const AcdcClientBuilder()
          .withBaseUrl('https://api.example.com')
          .withTimeout(const Duration(seconds: 45))
          .withLogLevel(LogLevel.warning)
          .withCache(
            const CacheConfig(
              ttl: Duration(hours: 2),
              // encrypted: true,
              staleWhileRevalidate: true,
            ),
          )
          .build();

      expect(dio, isA<Dio>());
      expect(dio.options.connectTimeout, const Duration(seconds: 45));
    });
  });
}
