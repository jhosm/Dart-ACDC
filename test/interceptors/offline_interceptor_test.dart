import 'package:dart_acdc/src/cache/cache_config.dart';
import 'package:dart_acdc/src/exceptions/acdc_network_exception.dart';
import 'package:dart_acdc/src/interceptors/offline_interceptor.dart';
import 'package:dart_acdc/src/interceptors/cache_interceptor.dart';
import 'package:dart_acdc/src/network_info/network_info.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'offline_interceptor_test.mocks.dart';

@GenerateMocks([NetworkInfo, RequestInterceptorHandler])
void main() {
  late MockNetworkInfo mockNetworkInfo;
  late MockRequestInterceptorHandler mockHandler;
  late MemCacheStore cacheStore;
  late CacheConfig cacheConfig;
  late OfflineInterceptor interceptor;

  setUp(() {
    mockNetworkInfo = MockNetworkInfo();
    mockHandler = MockRequestInterceptorHandler();
    cacheStore = MemCacheStore();
    cacheConfig = const CacheConfig();
    interceptor = OfflineInterceptor(
      networkInfo: mockNetworkInfo,
      cacheStore: cacheStore,
      cacheConfig: cacheConfig,
    );
  });

  tearDown(() {
    cacheStore.close();
  });

  group('OfflineInterceptor', () {
    test('proceeds when online', () async {
      when(mockNetworkInfo.isConnected).thenReturn(true);

      final options = RequestOptions(path: '/test');
      await interceptor.onRequest(options, mockHandler);

      verify(mockHandler.next(options)).called(1);
      verifyNever(mockHandler.resolve(any));
      verifyNever(mockHandler.reject(any));
    });

    test('proceeds when forced network even if offline', () async {
      when(mockNetworkInfo.isConnected).thenReturn(false);

      final options = RequestOptions(
        path: '/test',
        extra: {'force_network': true},
      );
      await interceptor.onRequest(options, mockHandler);

      verify(mockHandler.next(options)).called(1);
    });

    test('returns cached response when offline and cache available', () async {
      when(mockNetworkInfo.isConnected).thenReturn(false);

      // Seed cache
      final options = RequestOptions(
        baseUrl: 'https://api.example.com',
        path: '/test',
        method: 'GET',
        responseType: ResponseType.bytes,
      );
      final key = AcdcCacheInterceptor.buildCacheKeyWithUserIsolation(options);
      final cachedResponse = CacheResponse(
        statusCode: 200,
        cacheControl: CacheControl(),
        content: [1, 2, 3], // dummy bytes
        date: DateTime.now(),
        eTag: '123',
        expires: null,
        headers: null,
        key: key,
        lastModified: null,
        maxStale: null,
        priority: CachePriority.normal,
        requestDate: DateTime.now(),
        responseDate: DateTime.now(),
        url: 'https://api.example.com/test',
      );
      await cacheStore.set(cachedResponse);

      await interceptor.onRequest(options, mockHandler);

      final captured = verify(mockHandler.resolve(captureAny)).captured;
      final response = captured.first as Response;

      expect(response.statusCode, 200);
      expect(response.extra['fromOfflineCache'], true);
      expect(response.headers.value('X-ACDC-From-Cache'), 'true');
    });

    test('fails fast when offline, cache miss, and failFast is true', () async {
      when(mockNetworkInfo.isConnected).thenReturn(false);

      final options = RequestOptions(
        baseUrl: 'https://api.example.com',
        path: '/test',
        method: 'GET',
      );

      // Default failFast is true
      await interceptor.onRequest(options, mockHandler);

      final captured = verify(mockHandler.reject(captureAny)).captured;
      final error = captured.first as AcdcNetworkException;

      expect(error.networkErrorType, NetworkErrorType.noConnection);
    });

    test('proceeds when offline, cache miss, and failFast is false', () async {
      when(mockNetworkInfo.isConnected).thenReturn(false);

      interceptor = OfflineInterceptor(
        networkInfo: mockNetworkInfo,
        cacheStore: cacheStore,
        cacheConfig: cacheConfig,
        failFast: false,
      );

      final options = RequestOptions(
        baseUrl: 'https://api.example.com',
        path: '/test',
        method: 'GET',
      );

      await interceptor.onRequest(options, mockHandler);

      verify(mockHandler.next(options)).called(1);
    });

    test('ignores cache and fails fast for non-GET/HEAD requests', () async {
      when(mockNetworkInfo.isConnected).thenReturn(false);

      final options = RequestOptions(
        baseUrl: 'https://api.example.com',
        path: '/test',
        method: 'POST',
      );

      await interceptor.onRequest(options, mockHandler);

      verify(mockHandler.reject(any)).called(1);
    });
  });
}
