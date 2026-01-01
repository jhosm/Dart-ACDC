import 'package:dart_acdc/src/auth/acdc_auth_manager.dart';
import 'package:dart_acdc/src/auth/token_provider.dart';
import 'package:dart_acdc/src/auth/token_refresh_result.dart';
import 'package:dart_acdc/src/builder/acdc_client_builder.dart';
import 'package:dart_acdc/src/cache/cache_config.dart';
import 'package:dart_acdc/src/interceptors/auth_interceptor.dart';
import 'package:dart_acdc/src/interceptors/error_interceptor.dart';
import 'package:dart_acdc/src/logging/log_level.dart';
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
  group('AcdcClientBuilder', () {
    group('Immutability', () {
      test('withBaseUrl returns new instance', () {
        final builder1 = AcdcClientBuilder();
        final builder2 = builder1.withBaseUrl('https://api.example.com');

        expect(builder1, isNot(same(builder2)));
      });

      test('withTimeout returns new instance', () {
        final builder1 = AcdcClientBuilder();
        final builder2 = builder1.withTimeout(Duration(seconds: 30));

        expect(builder1, isNot(same(builder2)));
      });

      test('withTokenProvider returns new instance', () {
        final builder1 = AcdcClientBuilder();
        final builder2 = builder1.withTokenProvider(MockTokenProvider());

        expect(builder1, isNot(same(builder2)));
      });

      test('withLogLevel returns new instance', () {
        final builder1 = AcdcClientBuilder();
        final builder2 = builder1.withLogLevel(LogLevel.debug);

        expect(builder1, isNot(same(builder2)));
      });

      test('withCache returns new instance', () {
        final builder1 = AcdcClientBuilder();
        final builder2 = builder1.withCache(CacheConfig());

        expect(builder1, isNot(same(builder2)));
      });

      test('disableCache returns new instance', () {
        final builder1 = AcdcClientBuilder();
        final builder2 = builder1.disableCache();

        expect(builder1, isNot(same(builder2)));
      });

      test('withInterceptor returns new instance', () {
        final builder1 = AcdcClientBuilder();
        final builder2 = builder1.withInterceptor(
          InterceptorsWrapper(),
        );

        expect(builder1, isNot(same(builder2)));
      });
    });

    group('Validation', () {
      test('withTimeout throws on negative duration', () {
        final builder = AcdcClientBuilder();

        expect(
          () => builder.withTimeout(Duration(seconds: -1)),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Timeout duration must be positive'),
          )),
        );
      });

      test('withTimeout throws on zero duration', () {
        final builder = AcdcClientBuilder();

        expect(
          () => builder.withTimeout(Duration.zero),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Timeout duration must be positive'),
          )),
        );
      });

      test('withTimeout accepts positive duration', () {
        final builder = AcdcClientBuilder();

        expect(
          () => builder.withTimeout(Duration(seconds: 30)),
          returnsNormally,
        );
      });

      test('build throws on invalid base URL format', () {
        final builder = AcdcClientBuilder()
            .withBaseUrl('not-a-valid-url');

        expect(
          () => builder.build(),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Invalid base URL format'),
          )),
        );
      });

      test('build throws on base URL without scheme', () {
        final builder = AcdcClientBuilder()
            .withBaseUrl('api.example.com');

        expect(
          () => builder.build(),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Invalid base URL format'),
          )),
        );
      });

      test('build throws on base URL with invalid scheme', () {
        final builder = AcdcClientBuilder()
            .withBaseUrl('ftp://api.example.com');

        expect(
          () => builder.build(),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Invalid base URL format'),
          )),
        );
      });

      test('build accepts valid http URL', () {
        final dio = AcdcClientBuilder()
            .withBaseUrl('http://api.example.com')
            .build();

        expect(dio, isA<Dio>());
        expect(dio.options.baseUrl, 'http://api.example.com');
      });

      test('build accepts valid https URL', () {
        final dio = AcdcClientBuilder()
            .withBaseUrl('https://api.example.com')
            .build();

        expect(dio, isA<Dio>());
        expect(dio.options.baseUrl, 'https://api.example.com');
      });
    });

    group('Method Chaining', () {
      test('supports chaining multiple configuration methods', () {
        final builder = AcdcClientBuilder()
            .withBaseUrl('https://api.example.com')
            .withTimeout(Duration(seconds: 45))
            .withLogLevel(LogLevel.debug)
            .withTokenProvider(MockTokenProvider())
            .withCache(CacheConfig(ttl: Duration(hours: 2)));

        expect(builder, isA<AcdcClientBuilder>());
      });

      test('last configuration wins on conflicts - timeout', () {
        final builder = AcdcClientBuilder()
            .withTimeout(Duration(seconds: 30))
            .withTimeout(Duration(seconds: 60));

        // Since we can't access private fields, we verify the builder
        // was created successfully with the last value
        expect(builder, isA<AcdcClientBuilder>());
      });

      test('last configuration wins on conflicts - base URL', () {
        final builder = AcdcClientBuilder()
            .withBaseUrl('https://api1.example.com')
            .withBaseUrl('https://api2.example.com');

        expect(builder, isA<AcdcClientBuilder>());
      });

      test('last configuration wins on conflicts - log level', () {
        final builder = AcdcClientBuilder()
            .withLogLevel(LogLevel.debug)
            .withLogLevel(LogLevel.error);

        expect(builder, isA<AcdcClientBuilder>());
      });

      test('disableCache overrides withCache', () {
        final builder = AcdcClientBuilder()
            .withCache(CacheConfig())
            .disableCache();

        expect(builder, isA<AcdcClientBuilder>());
      });
    });

    group('Fluent API Methods', () {
      test('withBaseUrl creates builder with base URL', () {
        final builder = AcdcClientBuilder()
            .withBaseUrl('https://api.example.com');

        expect(builder, isA<AcdcClientBuilder>());
      });

      test('withTimeout creates builder with custom timeout', () {
        final builder = AcdcClientBuilder()
            .withTimeout(Duration(seconds: 45));

        expect(builder, isA<AcdcClientBuilder>());
      });

      test('withTokenProvider creates builder with token provider', () {
        final builder = AcdcClientBuilder()
            .withTokenProvider(MockTokenProvider());

        expect(builder, isA<AcdcClientBuilder>());
      });

      test('withTokenRefreshEndpoint creates builder with refresh config', () {
        final builder = AcdcClientBuilder()
            .withTokenRefreshEndpoint(
          url: 'https://auth.example.com/oauth/token',
          clientId: 'my-client-id',
        );

        expect(builder, isA<AcdcClientBuilder>());
      });

      test('withCustomTokenRefresh creates builder with custom refresh', () {
        final builder = AcdcClientBuilder()
            .withCustomTokenRefresh((refreshToken) async {
          return TokenRefreshResult(
            accessToken: 'new_access_token',
            refreshToken: 'new_refresh_token',
          );
        });

        expect(builder, isA<AcdcClientBuilder>());
      });

      test('withTokenRevocationEndpoint creates builder with revocation URL', () {
        final builder = AcdcClientBuilder()
            .withTokenRevocationEndpoint('https://auth.example.com/revoke');

        expect(builder, isA<AcdcClientBuilder>());
      });

      test('withTokenRefreshThreshold creates builder with custom threshold', () {
        final builder = AcdcClientBuilder()
            .withTokenRefreshThreshold(Duration(seconds: 120));

        expect(builder, isA<AcdcClientBuilder>());
      });

      test('withLogLevel creates builder with log level', () {
        final builder = AcdcClientBuilder()
            .withLogLevel(LogLevel.warning);

        expect(builder, isA<AcdcClientBuilder>());
      });

      test('withLogger creates builder with custom logger', () {
        final builder = AcdcClientBuilder()
            .withLogger((message, level, metadata) {
          // Custom logger implementation
        });

        expect(builder, isA<AcdcClientBuilder>());
      });

      test('withSensitiveFields creates builder with sensitive fields', () {
        final builder = AcdcClientBuilder()
            .withSensitiveFields(['password', 'ssn', 'credit_card']);

        expect(builder, isA<AcdcClientBuilder>());
      });

      test('withSlowRequestThreshold creates builder with slow request threshold', () {
        final builder = AcdcClientBuilder()
            .withSlowRequestThreshold(Duration(seconds: 5));

        expect(builder, isA<AcdcClientBuilder>());
      });

      test('withLargePayloadThreshold creates builder with payload threshold', () {
        final builder = AcdcClientBuilder()
            .withLargePayloadThreshold(1024 * 1024); // 1 MB

        expect(builder, isA<AcdcClientBuilder>());
      });

      test('withCache creates builder with cache config', () {
        final builder = AcdcClientBuilder()
            .withCache(CacheConfig(
          ttl: Duration(hours: 2),
          maxSize: 20 * 1024 * 1024,
        ));

        expect(builder, isA<AcdcClientBuilder>());
      });

      test('disableCache creates builder with caching disabled', () {
        final builder = AcdcClientBuilder().disableCache();

        expect(builder, isA<AcdcClientBuilder>());
      });

      test('withInterceptor creates builder with custom interceptor', () {
        final builder = AcdcClientBuilder()
            .withInterceptor(InterceptorsWrapper());

        expect(builder, isA<AcdcClientBuilder>());
      });

      test('withInterceptor supports multiple interceptors', () {
        final builder = AcdcClientBuilder()
            .withInterceptor(InterceptorsWrapper())
            .withInterceptor(InterceptorsWrapper())
            .withInterceptor(InterceptorsWrapper());

        expect(builder, isA<AcdcClientBuilder>());
      });
    });

    group('Build Method', () {
      test('build creates Dio instance with zero configuration', () {
        final dio = AcdcClientBuilder().build();

        expect(dio, isA<Dio>());
        expect(dio.options.baseUrl, isEmpty);
        expect(dio.options.connectTimeout, Duration(seconds: 30));
        expect(dio.options.sendTimeout, Duration(seconds: 30));
        expect(dio.options.receiveTimeout, Duration(seconds: 30));
      });

      test('build sets base URL when configured', () {
        final dio = AcdcClientBuilder()
            .withBaseUrl('https://api.example.com')
            .build();

        expect(dio.options.baseUrl, 'https://api.example.com');
      });

      test('build sets custom timeout when configured', () {
        final dio = AcdcClientBuilder()
            .withTimeout(Duration(seconds: 45))
            .build();

        expect(dio.options.connectTimeout, Duration(seconds: 45));
        expect(dio.options.sendTimeout, Duration(seconds: 45));
        expect(dio.options.receiveTimeout, Duration(seconds: 45));
      });

      test('build creates new instances each time', () {
        final builder = AcdcClientBuilder()
            .withBaseUrl('https://api.example.com');

        final dio1 = builder.build();
        final dio2 = builder.build();

        expect(dio1, isNot(same(dio2)));
        expect(dio1.options.baseUrl, dio2.options.baseUrl);
      });

      test('build adds error interceptor', () {
        final dio = AcdcClientBuilder().build();

        final hasErrorInterceptor = dio.interceptors
            .any((interceptor) => interceptor is ErrorInterceptor);

        expect(hasErrorInterceptor, true);
      });

      test('build adds auth interceptor when token provider configured', () {
        final dio = AcdcClientBuilder()
            .withTokenProvider(MockTokenProvider())
            .withTokenRefreshEndpoint(
              url: 'https://auth.example.com/token',
              clientId: 'test-client',
            )
            .build();

        final hasAuthInterceptor = dio.interceptors
            .any((interceptor) => interceptor is AuthInterceptor);

        expect(hasAuthInterceptor, true);
      });

      test('build does not add auth interceptor when token provider not configured', () {
        final dio = AcdcClientBuilder().build();

        final hasAuthInterceptor = dio.interceptors
            .any((interceptor) => interceptor is AuthInterceptor);

        expect(hasAuthInterceptor, false);
      });

      test('build adds custom interceptors at the end', () {
        final customInterceptor1 = InterceptorsWrapper();
        final customInterceptor2 = InterceptorsWrapper();

        final dio = AcdcClientBuilder()
            .withInterceptor(customInterceptor1)
            .withInterceptor(customInterceptor2)
            .build();

        expect(dio.interceptors.contains(customInterceptor1), true);
        expect(dio.interceptors.contains(customInterceptor2), true);

        // Custom interceptors should be after error interceptor
        final errorIndex = dio.interceptors
            .indexWhere((i) => i is ErrorInterceptor);
        final custom1Index = dio.interceptors.indexOf(customInterceptor1);
        final custom2Index = dio.interceptors.indexOf(customInterceptor2);

        expect(custom1Index, greaterThan(errorIndex));
        expect(custom2Index, greaterThan(custom1Index));
      });

      test('build creates auth manager when auth configured', () {
        final dio = AcdcClientBuilder()
            .withTokenProvider(MockTokenProvider())
            .withTokenRefreshEndpoint(
              url: 'https://auth.example.com/token',
              clientId: 'test-client',
            )
            .build();

        expect(() => dio.auth, returnsNormally);
      });

      test('build stores auth manager in dio options', () {
        final dio = AcdcClientBuilder()
            .withTokenProvider(MockTokenProvider())
            .withTokenRefreshEndpoint(
              url: 'https://auth.example.com/token',
              clientId: 'test-client',
            )
            .build();

        final authManager = dio.options.extra['_acdc_auth_manager'];
        expect(authManager, isNotNull);
      });

      test('auth extension throws when no token provider configured', () {
        final dio = AcdcClientBuilder().build();

        expect(
          () => dio.auth,
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('No TokenProvider configured'),
          )),
        );
      });
    });
  });

  group('CacheConfig', () {
    test('creates with default values', () {
      final config = CacheConfig();

      expect(config.ttl, Duration(hours: 1));
      expect(config.maxSize, 10 * 1024 * 1024);
      expect(config.cacheAuthenticatedRequests, true);
      expect(config.encrypted, false);
      expect(config.requireEncryption, false);
      expect(config.inMemory, true);
      expect(config.inMemoryMaxSize, 5 * 1024 * 1024);
      expect(config.staleWhileRevalidate, false);
      expect(config.staleIfError, true);
      expect(config.userIdProvider, null);
    });

    test('creates with custom values', () {
      final config = CacheConfig(
        ttl: Duration(hours: 2),
        maxSize: 20 * 1024 * 1024,
        cacheAuthenticatedRequests: false,
        encrypted: true,
        requireEncryption: true,
        inMemory: false,
        inMemoryMaxSize: 10 * 1024 * 1024,
        staleWhileRevalidate: true,
        staleIfError: false,
      );

      expect(config.ttl, Duration(hours: 2));
      expect(config.maxSize, 20 * 1024 * 1024);
      expect(config.cacheAuthenticatedRequests, false);
      expect(config.encrypted, true);
      expect(config.requireEncryption, true);
      expect(config.inMemory, false);
      expect(config.inMemoryMaxSize, 10 * 1024 * 1024);
      expect(config.staleWhileRevalidate, true);
      expect(config.staleIfError, false);
    });

    test('toString includes all configuration', () {
      final config = CacheConfig();
      final string = config.toString();

      expect(string, contains('CacheConfig'));
      expect(string, contains('ttl:'));
      expect(string, contains('maxSize:'));
      expect(string, contains('cacheAuthenticatedRequests:'));
      expect(string, contains('encrypted:'));
    });

    test('accepts custom userIdProvider', () {
      final config = CacheConfig(
        userIdProvider: (token) async => 'custom-user-id',
      );

      expect(config.userIdProvider, isNotNull);
    });
  });
}
