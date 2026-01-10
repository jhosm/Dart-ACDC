import 'package:dart_acdc/src/cache/cache_config.dart';
import 'package:dart_acdc/src/interceptors/cache_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:test/test.dart';

void main() {
  group('Cache User Isolation', () {
    late Dio dio;
    late AcdcCacheInterceptor cacheInterceptor;

    setUp(() {
      dio = Dio();
      dio.options.baseUrl = 'https://api.example.com';
      cacheInterceptor = AcdcCacheInterceptor(
        config: const CacheConfig(),
        store: MemCacheStore(),
      );
      dio.interceptors.add(cacheInterceptor);
    });

    group('User ID Extraction', () {
      test('extracts user ID from Bearer token with sub claim', () async {
        // JWT with sub claim
        const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJzdWIiOiJ1c2VyLTEyMyIsImV4cCI6OTk5OTk5OTk5OX0.'
            'Kd-3Qx5PxQvQx5PxQvQx5PxQvQx5PxQvQx5PxQvQxQ';

        final options = RequestOptions(
          path: '/users/profile',
          method: 'GET',
        );
        options.headers['Authorization'] = 'Bearer $token';

        // Extract user ID
        await cacheInterceptor.onRequest(
          options,
          RequestInterceptorHandler(),
        );

        // Verify user ID was stored in extras
        expect(options.extra['_acdc_user_id'], equals('user-123'));
      });

      test('extracts user ID from token without Bearer prefix', () async {
        const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJzdWIiOiJ1c2VyLTQ1NiIsImV4cCI6OTk5OTk5OTk5OX0.'
            'someSignature';

        final options = RequestOptions(
          path: '/users/profile',
          method: 'GET',
        );
        options.headers['Authorization'] = token;

        await cacheInterceptor.onRequest(
          options,
          RequestInterceptorHandler(),
        );

        expect(options.extra['_acdc_user_id'], equals('user-456'));
      });

      test(
          'marks request as unauthenticated when Authorization header is missing',
          () async {
        final options = RequestOptions(
          path: '/public/data',
          method: 'GET',
        );

        await cacheInterceptor.onRequest(
          options,
          RequestInterceptorHandler(),
        );

        expect(options.extra['_acdc_has_auth'], isFalse);
        expect(options.extra.containsKey('_acdc_user_id'), isFalse);
      });

      test('marks as authenticated but no user ID for invalid JWT', () async {
        final options = RequestOptions(
          path: '/users/profile',
          method: 'GET',
        );
        options.headers['Authorization'] = 'Bearer invalid-token';

        await cacheInterceptor.onRequest(
          options,
          RequestInterceptorHandler(),
        );

        expect(options.extra['_acdc_has_auth'], isTrue);
        expect(options.extra.containsKey('_acdc_user_id'), isFalse);
      });

      test('uses custom userIdProvider when provided', () async {
        // Custom provider that returns a fixed user ID
        final customCache = AcdcCacheInterceptor(
          config: CacheConfig(
            userIdProvider: (token) async => 'custom-user-id',
          ),
          store: MemCacheStore(),
        );
        dio.interceptors.clear();
        dio.interceptors.add(customCache);

        final options = RequestOptions(
          path: '/users/profile',
          method: 'GET',
        );
        options.headers['Authorization'] = 'Bearer any-token';

        await customCache.onRequest(
          options,
          RequestInterceptorHandler(),
        );

        expect(options.extra['_acdc_user_id'], equals('custom-user-id'));
      });

      test('falls back to JWT extraction when custom provider fails', () async {
        final customCache = AcdcCacheInterceptor(
          config: CacheConfig(
            userIdProvider: (token) async => throw Exception('Provider failed'),
          ),
          store: MemCacheStore(),
        );

        // Valid JWT token
        const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJzdWIiOiJ1c2VyLTEyMyIsImV4cCI6OTk5OTk5OTk5OX0.'
            'someSignature';

        final options = RequestOptions(
          path: '/users/profile',
          method: 'GET',
        );
        options.headers['Authorization'] = 'Bearer $token';

        await customCache.onRequest(
          options,
          RequestInterceptorHandler(),
        );

        // Should fall back to JWT extraction
        expect(options.extra['_acdc_user_id'], equals('user-123'));
      });
    });

    group('Cache Key Generation', () {
      test('generates user-isolated cache key for authenticated request', () {
        final options = RequestOptions(
          path: '/users/profile',
          method: 'GET',
        );
        options.extra['_acdc_has_auth'] = true;
        options.extra['_acdc_user_id'] = 'user-123';

        final cacheKey =
            AcdcCacheInterceptor.buildCacheKeyWithUserIsolation(options);

        // Verify user ID is included in the cache key
        expect(cacheKey, contains('user-123'));
        // Verify key is not empty (caching is enabled)
        expect(cacheKey, isNotEmpty);
      });

      test('generates shared cache key for unauthenticated request', () {
        final options = RequestOptions(
          path: '/public/data',
          method: 'GET',
        );
        options.extra['_acdc_has_auth'] = false;
        // No user ID

        final cacheKey =
            AcdcCacheInterceptor.buildCacheKeyWithUserIsolation(options);

        // Should return standard key (not empty)
        expect(cacheKey, isNotEmpty);
        // Should NOT contain a user ID
        expect(cacheKey, isNot(contains(':')));
      });

      test('returns empty key when authenticated but user ID is missing', () {
        final options = RequestOptions(
          path: '/users/profile',
          method: 'GET',
        );
        options.extra['_acdc_has_auth'] = true;
        // No user ID set

        final cacheKey =
            AcdcCacheInterceptor.buildCacheKeyWithUserIsolation(options);

        // Empty key disables caching for security
        expect(cacheKey, equals(''));
      });

      test('returns empty key when user ID is empty string', () {
        final options = RequestOptions(
          path: '/users/profile',
          method: 'GET',
        );
        options.extra['_acdc_has_auth'] = true;
        options.extra['_acdc_user_id'] = '';

        final cacheKey =
            AcdcCacheInterceptor.buildCacheKeyWithUserIsolation(options);

        expect(cacheKey, equals(''));
      });

      test('generates different cache keys for different users', () {
        final options1 = RequestOptions(
          path: '/users/profile',
          method: 'GET',
        );
        options1.extra['_acdc_has_auth'] = true;
        options1.extra['_acdc_user_id'] = 'user-123';

        final options2 = RequestOptions(
          path: '/users/profile',
          method: 'GET',
        );
        options2.extra['_acdc_has_auth'] = true;
        options2.extra['_acdc_user_id'] = 'user-456';

        final key1 =
            AcdcCacheInterceptor.buildCacheKeyWithUserIsolation(options1);
        final key2 =
            AcdcCacheInterceptor.buildCacheKeyWithUserIsolation(options2);

        // Keys should be different for different users
        expect(key1, isNot(equals(key2)));
        expect(key1, contains('user-123'));
        expect(key2, contains('user-456'));
      });

      test('generates same cache key for same user across token refreshes', () {
        // Simulate same user with different tokens
        final options1 = RequestOptions(
          path: '/users/profile',
          method: 'GET',
        );
        options1.extra['_acdc_has_auth'] = true;
        options1.extra['_acdc_user_id'] = 'user-123';

        final options2 = RequestOptions(
          path: '/users/profile',
          method: 'GET',
        );
        options2.extra['_acdc_has_auth'] = true;
        options2.extra['_acdc_user_id'] = 'user-123';

        final key1 =
            AcdcCacheInterceptor.buildCacheKeyWithUserIsolation(options1);
        final key2 =
            AcdcCacheInterceptor.buildCacheKeyWithUserIsolation(options2);

        // Keys should be identical for same user
        expect(key1, equals(key2));
      });
    });

    group('Cache Clearing', () {
      test('clearCache method is available and completes', () async {
        await expectLater(
          cacheInterceptor.clearCache(),
          completes,
        );
      });

      test('clearCacheForUrl method is available and completes', () async {
        await expectLater(
          cacheInterceptor.clearCacheForUrl('https://api.example.com/users'),
          completes,
        );
      });
    });

    group('Integration Scenarios', () {
      test('different users cannot access each others cached data', () async {
        // User A makes a request
        const tokenA = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJzdWIiOiJ1c2VyLWEiLCJleHAiOjk5OTk5OTk5OTl9.'
            'signatureA';

        final optionsA = RequestOptions(
          path: '/users/profile',
          method: 'GET',
        );
        optionsA.headers['Authorization'] = 'Bearer $tokenA';

        await cacheInterceptor.onRequest(
          optionsA,
          RequestInterceptorHandler(),
        );

        final keyA =
            AcdcCacheInterceptor.buildCacheKeyWithUserIsolation(optionsA);

        // User B makes the same request
        const tokenB = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJzdWIiOiJ1c2VyLWIiLCJleHAiOjk5OTk5OTk5OTl9.'
            'signatureB';

        final optionsB = RequestOptions(
          path: '/users/profile',
          method: 'GET',
        );
        optionsB.headers['Authorization'] = 'Bearer $tokenB';

        await cacheInterceptor.onRequest(
          optionsB,
          RequestInterceptorHandler(),
        );

        final keyB =
            AcdcCacheInterceptor.buildCacheKeyWithUserIsolation(optionsB);

        // Cache keys must be different
        expect(keyA, isNot(equals(keyB)));
      });

      test('same user with refreshed token uses same cache', () async {
        // User with original token
        const token1 = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJzdWIiOiJ1c2VyLTEyMyIsImV4cCI6MTcwMDAwMDAwMH0.'
            'signature1';

        final options1 = RequestOptions(
          path: '/users/profile',
          method: 'GET',
        );
        options1.headers['Authorization'] = 'Bearer $token1';

        await cacheInterceptor.onRequest(
          options1,
          RequestInterceptorHandler(),
        );

        final key1 =
            AcdcCacheInterceptor.buildCacheKeyWithUserIsolation(options1);

        // Same user with refreshed token (different exp)
        const token2 = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJzdWIiOiJ1c2VyLTEyMyIsImV4cCI6MTgwMDAwMDAwMH0.'
            'signature2';

        final options2 = RequestOptions(
          path: '/users/profile',
          method: 'GET',
        );
        options2.headers['Authorization'] = 'Bearer $token2';

        await cacheInterceptor.onRequest(
          options2,
          RequestInterceptorHandler(),
        );

        final key2 =
            AcdcCacheInterceptor.buildCacheKeyWithUserIsolation(options2);

        // Cache keys should be identical (same user ID)
        expect(key1, equals(key2));
      });

      test('unauthenticated requests use shared cache', () async {
        final options = RequestOptions(
          path: '/public/data',
          method: 'GET',
        );
        // No Authorization header

        await cacheInterceptor.onRequest(
          options,
          RequestInterceptorHandler(),
        );

        final cacheKey =
            AcdcCacheInterceptor.buildCacheKeyWithUserIsolation(options);

        // Should return standard key (shared cache for public data)
        expect(cacheKey, isNotEmpty);
        // Should not have user isolation suffix
        expect(options.extra['_acdc_has_auth'], isFalse);
        expect(options.extra.containsKey('_acdc_user_id'), isFalse);
      });

      test('authenticated requests without user ID are not cached', () async {
        final options = RequestOptions(
          path: '/users/profile',
          method: 'GET',
        );
        // Invalid JWT that can't be decoded
        options.headers['Authorization'] = 'Bearer invalid-jwt-token';

        await cacheInterceptor.onRequest(
          options,
          RequestInterceptorHandler(),
        );

        final cacheKey =
            AcdcCacheInterceptor.buildCacheKeyWithUserIsolation(options);

        // Should return empty key (no caching for security)
        expect(cacheKey, equals(''));
        // Should be marked as authenticated but no user ID
        expect(options.extra['_acdc_has_auth'], isTrue);
        expect(options.extra.containsKey('_acdc_user_id'), isFalse);
      });
    });
  });
}
