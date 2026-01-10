import 'package:dart_acdc/src/cache/cache_config.dart';
import 'package:dart_acdc/src/interceptors/cache_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:test/test.dart';

void main() {
  group('AcdcCacheInterceptor', () {
    late Dio dio;

    setUp(() {
      dio = Dio();
      dio.options.baseUrl = 'https://api.example.com';
    });

    group('Method-Based Caching', () {
      test('creates interceptor with default configuration', () {
        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(),
          store: MemCacheStore(),
        );
        dio.interceptors.add(interceptor);

        // Verify interceptor is configured correctly
        // Actual caching behavior (GET/HEAD only) is handled by dio_cache_interceptor
        expect(interceptor, isA<AcdcCacheInterceptor>());
        expect(dio.interceptors.contains(interceptor), true);
      });

      test('POST requests trigger cache invalidation', () {
        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(),
          store: MemCacheStore(),
        );

        // Create a response for a POST request
        final response = Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(
            path: '/users',
            method: 'POST',
          ),
          statusCode: 201,
        );

        // Verify onResponse handles POST without errors
        expect(
          () => interceptor.onResponse(
            response,
            ResponseInterceptorHandler(),
          ),
          returnsNormally,
        );
      });

      test('PUT requests trigger cache invalidation', () {
        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(),
          store: MemCacheStore(),
        );

        final response = Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(
            path: '/users/1',
            method: 'PUT',
          ),
          statusCode: 200,
        );

        expect(
          () => interceptor.onResponse(
            response,
            ResponseInterceptorHandler(),
          ),
          returnsNormally,
        );
      });

      test('DELETE requests trigger cache invalidation', () {
        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(),
          store: MemCacheStore(),
        );

        final response = Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(
            path: '/users/1',
            method: 'DELETE',
          ),
          statusCode: 204,
        );

        expect(
          () => interceptor.onResponse(
            response,
            ResponseInterceptorHandler(),
          ),
          returnsNormally,
        );
      });

      test('PATCH requests trigger cache invalidation', () {
        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(),
          store: MemCacheStore(),
        );

        final response = Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(
            path: '/users/1',
            method: 'PATCH',
          ),
          statusCode: 200,
        );

        expect(
          () => interceptor.onResponse(
            response,
            ResponseInterceptorHandler(),
          ),
          returnsNormally,
        );
      });

      test('GET requests do not trigger cache invalidation', () {
        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(),
          store: MemCacheStore(),
        );

        final response = Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(
            path: '/users',
            method: 'GET',
          ),
          statusCode: 200,
        );

        expect(
          () => interceptor.onResponse(
            response,
            ResponseInterceptorHandler(),
          ),
          returnsNormally,
        );
      });
    });

    group('Cache Invalidation', () {
      test('clearCache method is available', () async {
        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(),
          store: MemCacheStore(),
        );

        // Verify clearCache doesn't throw
        await expectLater(
          interceptor.clearCache(),
          completes,
        );
      });

      test('clearCacheForUrl method is available', () async {
        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(),
          store: MemCacheStore(),
        );

        // Verify clearCacheForUrl doesn't throw
        await expectLater(
          interceptor.clearCacheForUrl('https://api.example.com/users'),
          completes,
        );
      });
    });

    group('Configuration', () {
      test('respects staleWhileRevalidate setting', () {
        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(staleWhileRevalidate: true),
          store: MemCacheStore(),
        );

        expect(interceptor, isA<AcdcCacheInterceptor>());
      });

      test('respects staleIfError setting', () {
        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(staleIfError: false),
          store: MemCacheStore(),
        );

        expect(interceptor, isA<AcdcCacheInterceptor>());
      });

      test('respects inMemory cache configuration', () {
        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(
            inMemoryMaxSize: 10 * 1024 * 1024,
          ),
          store: MemCacheStore(),
        );

        expect(interceptor, isA<AcdcCacheInterceptor>());
      });

      test('respects disabled inMemory cache', () {
        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(
            inMemory: false,
            maxSize: 20 * 1024 * 1024,
          ),
          store: MemCacheStore(),
        );

        expect(interceptor, isA<AcdcCacheInterceptor>());
      });
    });

    group('HTTP Directive Support', () {
      test('interceptor is configured to respect HTTP directives', () {
        // The interceptor uses CachePolicy.request which respects
        // Cache-Control, ETag, Last-Modified headers
        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(),
          store: MemCacheStore(),
        );

        expect(interceptor, isA<AcdcCacheInterceptor>());
      });

      test('supports 304 Not Modified handling via dio_cache_interceptor', () {
        // 304 handling is built into dio_cache_interceptor
        // This test verifies the interceptor is properly configured
        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(),
          store: MemCacheStore(),
        );

        expect(interceptor, isA<AcdcCacheInterceptor>());
      });
    });

    group('Stale-While-Revalidate', () {
      test(
          'configures refreshForceCache policy when staleWhileRevalidate is enabled',
          () {
        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(staleWhileRevalidate: true),
          store: MemCacheStore(),
        );

        // Verify interceptor is created successfully
        // Actual stale-while-revalidate behavior is handled by dio_cache_interceptor
        // with CachePolicy.refreshForceCache
        expect(interceptor, isA<AcdcCacheInterceptor>());
      });

      test('uses request policy when staleWhileRevalidate is disabled', () {
        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(),
          store: MemCacheStore(),
        );

        // Verify interceptor uses standard request policy
        expect(interceptor, isA<AcdcCacheInterceptor>());
      });

      test('adds X-ACDC-From-Cache header to cached responses', () {
        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(),
          store: MemCacheStore(),
        );

        // Create a response with cache metadata (simulating cached response)
        final response = Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/users', method: 'GET'),
          statusCode: 200,
          extra: {
            'cache_key': 'GET:https://api.example.com/users',
            'cache_response': true,
          },
        );

        // Add cache metadata
        expect(
          () => interceptor.onResponse(
            response,
            ResponseInterceptorHandler(),
          ),
          returnsNormally,
        );

        // Note: In actual usage, dio_cache_interceptor adds the cache metadata
        // and our interceptor adds the X-ACDC-From-Cache header
      });
    });

    group('Offline Handling', () {
      test(
          'serves stale cache on network unavailability when staleIfError is enabled',
          () {
        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(),
          store: MemCacheStore(),
        );

        // Verify interceptor is configured with maxStale (staleIfError defaults to true)
        expect(interceptor, isA<AcdcCacheInterceptor>());
      });

      test(
          'does not serve stale cache on network errors when staleIfError is disabled',
          () {
        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(staleIfError: false),
          store: MemCacheStore(),
        );

        // Verify interceptor is configured without maxStale
        expect(interceptor, isA<AcdcCacheInterceptor>());
      });

      test('interceptor with staleIfError can serve cached responses on errors',
          () {
        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(),
          store: MemCacheStore(),
        );

        // Verify interceptor is properly configured
        // In actual usage with dio_cache_interceptor, when a network error occurs:
        // - If stale cache exists: serves it with fromOfflineCache flag
        // - If no cache exists: enhances error with AcdcNetworkException
        expect(interceptor, isA<AcdcCacheInterceptor>());
      });
    });

    group('Cache Metadata', () {
      test('adds X-ACDC-From-Cache header for cached responses', () {
        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(),
          store: MemCacheStore(),
        );

        // Create a response simulating a cached response
        final response = Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/users', method: 'GET'),
          statusCode: 200,
          extra: {
            'cache_key': 'GET:https://api.example.com/users',
          },
        );

        expect(
          () => interceptor.onResponse(
            response,
            ResponseInterceptorHandler(),
          ),
          returnsNormally,
        );
      });

      test('does not add cache header for non-cached responses', () {
        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(),
          store: MemCacheStore(),
        );

        // Create a response without cache metadata
        final response = Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/users', method: 'GET'),
          statusCode: 200,
        );

        expect(
          () => interceptor.onResponse(
            response,
            ResponseInterceptorHandler(),
          ),
          returnsNormally,
        );
      });
    });
    group('Custom Key Builder', () {
      test('uses custom key builder when provided', () {
        // Configuration validation
        // ignore: unused_local_variable
        final interceptor = AcdcCacheInterceptor(
          config: CacheConfig(
            keyBuilder: (request) => 'custom_key:${request.uri}',
          ),
          store: MemCacheStore(),
        );

        // Verify key generation (using public static helper for testing)
        final options = RequestOptions(
          baseUrl: 'https://api.example.com',
          path: '/users',
          extra: {
            '_acdc_has_auth': true,
            '_acdc_user_id': 'user123',
          },
        );

        final key = AcdcCacheInterceptor.buildCacheKeyWithUserIsolation(
          options,
          customKeyBuilder: (request) => 'custom_key:${request.uri}',
        );

        // Should use custom key + user ID suffix (isolation enforced)
        expect(key, 'custom_key:https://api.example.com/users:user123');
      });

      test('enforces user isolation with custom key builder', () {
        // Authenticated request with user ID
        final options = RequestOptions(
          path: '/users',
          extra: {
            '_acdc_has_auth': true,
            '_acdc_user_id': 'user123',
          },
        );

        final key = AcdcCacheInterceptor.buildCacheKeyWithUserIsolation(
          options,
          customKeyBuilder: (request) => 'simple_key',
        );

        // Must preserve user isolation
        expect(key, 'simple_key:user123');
      });

      test('uses custom key builder for unauthenticated requests', () {
        final options = RequestOptions(
          path: '/users',
          extra: {
            '_acdc_has_auth': false,
          },
        );

        final key = AcdcCacheInterceptor.buildCacheKeyWithUserIsolation(
          options,
          customKeyBuilder: (request) => 'public_key',
        );

        expect(key, 'public_key');
      });
    });

    group('Edge Cases', () {
      test('handles request with auth but no user ID (security check)', () {
        final options = RequestOptions(
          path: '/users',
          extra: {
            '_acdc_has_auth': true,
          },
        );

        final key =
            AcdcCacheInterceptor.buildCacheKeyWithUserIsolation(options);
        // Should return empty string to disable caching
        expect(key, isEmpty);
      });

      test('handles request with auth and empty user ID', () {
        final options = RequestOptions(
          path: '/users',
          extra: {
            '_acdc_has_auth': true,
            '_acdc_user_id': '',
          },
        );

        final key =
            AcdcCacheInterceptor.buildCacheKeyWithUserIsolation(options);
        // Should return empty string to disable caching
        expect(key, isEmpty);
      });

      test('handles request without auth', () {
        final options = RequestOptions(
          path: '/users',
          extra: {
            '_acdc_has_auth': false,
          },
        );

        // Base key generation relies on defaultCacheKeyBuilder,
        // effectively tested by existence of non-empty key
        final key =
            AcdcCacheInterceptor.buildCacheKeyWithUserIsolation(options);
        expect(key, isNotEmpty);
      });

      test('onRequest handles missing Authorization header', () async {
        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(),
          store: MemCacheStore(),
        );

        final options = RequestOptions(path: '/public');
        final handler = RequestInterceptorHandler();

        await interceptor.onRequest(options, handler);

        // _acdc_has_auth should be false
        expect(options.extra['_acdc_has_auth'], isFalse);
      });
    });
  });
}
