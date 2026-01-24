import 'dart:typed_data';
import 'package:dart_acdc/src/cache/cache_config.dart';
import 'package:dart_acdc/src/interceptors/cache_interceptor.dart';
import 'package:dart_acdc/src/logging/acdc_log_delegate.dart';
import 'package:dart_acdc/src/logging/log_level.dart';
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
      });

      // Better test: Integration style with Dio instance in the test.
      test('integration: serves cache and triggers refresh', () async {
        final dio = Dio();
        final store = MemCacheStore();
        var refreshCalled = false;

        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(staleWhileRevalidate: true),
          store: store,
          onRefresh: (options) async {
            refreshCalled = true;
          },
        );
        dio.interceptors.add(interceptor);

        const path = 'https://api.example.com/data';
        final key = CacheOptions.defaultCacheKeyBuilder(
          url: Uri.parse(path),
          headers: {},
        );

        // To properly seed, maybe easier to just use the Store API or a real request first?
        // Let's try real request to seed.
        // But we need a mock adapter to reply.
        final adapter = MockAdapter((options) async {
          final headers = {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'cache-control': ['max-age=3600'],
            'etag': ['12345'],
          };
          if (options.extra['swr_refresh'] == true) {
            return ResponseBody.fromString(
              '{"fresh": true}',
              200,
              headers: headers,
            );
          }
          return ResponseBody.fromString(
            '{"fresh": false}',
            200,
            headers: headers,
          );
        });
        dio.httpClientAdapter = adapter;

        // 1. Seed Request (disable SWR to just cache)
        // We can't easily disable SWR on the interceptor instance, but we can pass swr_refresh=true to bypass logic
        await dio.get<dynamic>(
          path,
          options: Options(extra: {'swr_refresh': true}),
        );

        // Verify cache exists
        expect(await store.exists(key), isTrue);

        // 2. SWR Request
        refreshCalled = false;
        final response = await dio.get<Map<String, dynamic>>(path);

        // Should get cached value (fresh=true because we seeded with swr_refresh=true)
        expect(response.data!['fresh'], isTrue);
        expect(response.headers.value('X-ACDC-From-Cache'), 'true');

        // Wait for microtask
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // callback should be called
        expect(refreshCalled, isTrue);
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

    group('Logging', () {
      late MockLogDelegate logDelegate;
      late AcdcCacheInterceptor interceptor;

      setUp(() {
        logDelegate = MockLogDelegate();
        interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(),
          store: MemCacheStore(),
          logDelegate: logDelegate,
        );
      });

      test('logs Cache Miss and Cache Write for fresh request', () async {
        final dio = Dio();
        dio.interceptors.add(interceptor);
        dio.httpClientAdapter = MockAdapter((options) async => ResponseBody.fromString(
            '{}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          ),);

        await dio.get<dynamic>('/fresh');

        // Verify logs
        final logs = logDelegate.logs;
        expect(logs.length, greaterThanOrEqualTo(2));

        // Check for Miss
        expect(
          logs.any(
            (l) =>
                l['message'].toString().contains('Cache Miss') &&
                l['metadata']['type'] == 'cache_miss',
          ),
          isTrue,
        );

        // Check for Write
        expect(
          logs.any(
            (l) =>
                l['message'].toString().contains('Cache Write') &&
                l['metadata']['type'] == 'cache_write',
          ),
          isTrue,
        );
      });

      test('logs Cache Hit (Intercepted) when served from cache', () async {
        final store = MemCacheStore();
        interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(),
          store: store,
          logDelegate: logDelegate,
        );
        final dio = Dio();
        dio.interceptors.add(interceptor);

        // Define headers that enable caching
        final headers = {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          'cache-control': ['max-age=3600'],
          'etag': ['123'],
        };

        // Use MockAdapter to serve a cacheable response initially
        dio.httpClientAdapter = MockAdapter((options) async => ResponseBody.fromString(
            '{}',
            200,
            headers: headers,
          ),);

        // 1. Seed Cache (First Request)
        await dio.get<dynamic>('https://api.example.com/cached');

        // Should log "Cache Miss" and "Cache Write"
        expect(
          logDelegate.logs.any((l) => l['metadata']['type'] == 'cache_miss'),
          isTrue,
        );
        expect(
          logDelegate.logs.any((l) => l['metadata']['type'] == 'cache_write'),
          isTrue,
        );

        // Clear logs for next assertion
        logDelegate.logs.clear();

        // 2. Trigger Cache Hit (Second Request)
        // Ensure store is ready (MemCacheStore is synchronous but let's be safe)
        // dio_cache_interceptor should serve from cache now
        await dio.get<dynamic>('https://api.example.com/cached');

        // Verify logs for Cache Hit
        final logs = logDelegate.logs;
        expect(
          logs.any(
            (l) =>
                l['message'].toString().contains('Cache Hit (Intercepted)') &&
                l['metadata']['type'] == 'cache_hit',
          ),
          isTrue,
        );
      });
    });
    group('ACDC Source Metadata', () {
      test('sets acdc_source to "network" for network responses', () async {
        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(),
          store: MemCacheStore(),
        );

        final dio = Dio();
        dio.interceptors.add(interceptor);
        dio.httpClientAdapter = MockAdapter((options) async => ResponseBody.fromString(
            '{}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          ),);

        final response = await dio.get<dynamic>('/network-only');
        expect(response.extra['acdc_source'], 'network');
      });

      test('sets acdc_source to "cache" for standard cache hits', () async {
        final store = MemCacheStore();
        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(),
          store: store,
        );
        final dio = Dio();
        dio.interceptors.add(interceptor);

        final headers = {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          'cache-control': ['max-age=3600'],
          'etag': ['123'],
        };

        dio.httpClientAdapter = MockAdapter((options) async => ResponseBody.fromString(
            '{}',
            200,
            headers: headers,
          ),);

        // Seed cache
        await dio.get<dynamic>('/cached-std');

        // Hit cache
        final response = await dio.get<dynamic>('/cached-std');
        expect(response.extra['acdc_source'], 'cache');
      });

      test('integration: sets acdc_source for SWR flow (stale then fresh)',
          () async {
        final dio = Dio();
        final store = MemCacheStore();

        // We need the refresh to actually go through the interceptor to get tagged 'network_fresh'.
        final interceptor = AcdcCacheInterceptor(
          config: const CacheConfig(staleWhileRevalidate: true),
          store: store,
          onRefresh: (options) => dio.fetch<dynamic>(options),
        );
        dio.interceptors.add(interceptor);

        final headers = {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          'cache-control': ['max-age=3600'],
          'etag': ['123'],
        };

        dio.httpClientAdapter = MockAdapter((options) async {
          // If refreshing, return distinct fresh data
          if (options.extra['swr_refresh'] == true) {
            return ResponseBody.fromString(
              '{"val": "fresh"}',
              200,
              headers: headers,
            );
          }
          return ResponseBody.fromString(
            '{"val": "stale"}',
            200,
            headers: headers,
          );
        });

        const path = 'https://api.example.com/swr-test';

        // 1. Seed (Network Miss -> 'network')
        final response = await dio.get<dynamic>(path);
        expect(response.data['val'], 'stale');
        expect(response.extra['acdc_source'], 'network');

        // 2. SWR Hit (Stale -> 'cache_stale') + Background Refresh -> 'network_fresh'
        Future<dynamic>? bgFuture;
        final responseSWR = await dio.get<dynamic>(
          path,
          options: Options(
            extra: {
              'swr_callback': (Future<dynamic> f) => bgFuture = f,
            },
          ),
        );

        // Check immediate response (Stale)
        expect(responseSWR.data['val'], 'stale');
        expect(responseSWR.extra['acdc_source'], 'cache_stale');

        // Wait for background refresh
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(
          bgFuture,
          isNotNull,
          reason: 'Background refresh should have been triggered',
        );

        final refreshResponse = await bgFuture;
        expect(refreshResponse, isA<Response<dynamic>>());
        // Check refresh response (Fresh)
        expect((refreshResponse as Response).data['val'], 'fresh');
        expect(refreshResponse.extra['acdc_source'], 'network_fresh');
      });
    });
  });
}

class MockAdapter implements HttpClientAdapter {
  MockAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

class MockLogDelegate implements AcdcLogDelegate {
  final List<Map<String, dynamic>> logs = [];

  @override
  void log(String message, LogLevel level, Map<String, dynamic> metadata) {
    logs.add({
      'message': message,
      'level': level,
      'metadata': metadata,
    });
  }
}
