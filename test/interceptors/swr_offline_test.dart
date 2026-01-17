import 'dart:typed_data';
import 'package:dart_acdc/src/cache/cache_config.dart';
import 'package:dart_acdc/src/interceptors/cache_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:test/test.dart';

void main() {
  group('AcdcCacheInterceptor - SWR Offline Bug Reproduction', () {
    test(
        'reproduction: returns acdc_source="cache" or "cache_stale" when offline',
        () async {
      final dio = Dio();
      final store = MemCacheStore();

      // Configure SWR
      final interceptor = AcdcCacheInterceptor(
        config: const CacheConfig(
          staleWhileRevalidate: true,
          staleIfError: true, // Allow serving stale content on error
        ),
        store: store,
      );
      dio.interceptors.add(interceptor);

      const path = 'https://api.example.com/data';
      final headers = {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        'cache-control': [
          'max-age=1'
        ], // Short max-age to ensure it becomes stale quickly
        'etag': ['12345'],
      };

      // Mock Adapter to simulate Network
      dio.httpClientAdapter = MockAdapter((options) async {
        // Simulate Offline by throwing an error if a specific header or flag is set
        // Or just fail for the second request
        if (options.extra['simulate_offline'] == true) {
          throw DioException(
            requestOptions: options, // Ensure requestOptions are passed
            type: DioExceptionType.connectionError,
            error: 'No Internet',
          );
        }

        return ResponseBody.fromString(
          '{"data": "fresh"}',
          200,
          headers: headers,
        );
      });

      // 1. Seed the Cache (Online)
      await dio.get<dynamic>(path);

      // Verify it's in cache
      final key = CacheOptions.defaultCacheKeyBuilder(
          url: Uri.parse(path), headers: {});
      expect(await store.exists(key), isTrue,
          reason: 'Response should be cached');

      // 2. Wait for cache to become stale (if max-age is respected directly)

      try {
        final response = await dio.get<dynamic>(
          path,
          options: Options(
            extra: {'simulate_offline': true},
          ),
        );

        // This is where we verify the bug.
        // User says it returns success (from cache) but acdc_source is wrong.
        print('Response Source: ${response.extra['acdc_source']}');

        expect(response.headers.value('X-ACDC-From-Cache'), 'true',
            reason: 'Should come from cache');
        expect(response.extra['acdc_source'], isNotNull,
            reason: 'acdc_source should not be null');
        expect(response.extra['acdc_source'], isNot('unknown'),
            reason: 'acdc_source should not be unknown');
        expect(response.extra['acdc_source'], anyOf('cache', 'cache_stale'),
            reason: 'acdc_source should be a valid cache type');
      } on DioException catch (e) {
        fail('Should have served from cache, but got error: $e');
      }
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
