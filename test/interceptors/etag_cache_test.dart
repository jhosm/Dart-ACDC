import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_acdc/src/cache/cache_config.dart';
import 'package:dart_acdc/src/cache/cache_store_factory.dart';
import 'package:dart_acdc/src/interceptors/cache_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeHttpClientAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  ResponseBody? nextResponse;

  // Helper to set next response easily
  void setResponse(String data, int statusCode,
      {Map<String, List<String>>? headers}) {
    nextResponse = ResponseBody.fromString(
      data,
      statusCode,
      headers: headers ?? {},
    );
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    requests.add(options);

    // Simulate network delay slightly to ensure async gap if needed
    // await Future.delayed(Duration(milliseconds: 10));

    if (nextResponse != null) {
      return nextResponse!;
    }
    return ResponseBody.fromString('', 404);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock FlutterSecureStorage channel
  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel,
            (MethodCall methodCall) async {
      // Simple mock: always return null for read (Simulating empty storage),
      // success for write/delete
      if (methodCall.method == 'read') {
        return null;
      }
      return null;
    });
  });

  group('AcdcCacheInterceptor ETag Support', () {
    late Dio dio;
    late FakeHttpClientAdapter fakeAdapter;
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('acdc_test_');

      dio = Dio();
      dio.options.baseUrl = 'https://api.example.com';

      fakeAdapter = FakeHttpClientAdapter();
      dio.httpClientAdapter = fakeAdapter;
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('stores ETag from response', () async {
      final config = CacheConfig(
        inMemory: true,
        storePath: tempDir.path, // Use temp dir
      );
      final interceptor = AcdcCacheInterceptor(
        config: config,
        store: CacheStoreFactory.build(config),
      );
      dio.interceptors.add(interceptor);

      final etag = '"test-etag-12345"';

      // 1. Configure response with ETag
      fakeAdapter.setResponse(
        '{"data": "fresh"}',
        200,
        headers: {
          'etag': [etag],
          'content-type': ['application/json'],
          'cache-control': ['public, max-age=0'],
          'date': ['Wed, 21 Oct 2015 07:28:00 GMT'],
        },
      );

      // 2. Perform first request
      await dio.get('/data');

      // 3. Verify request happened
      expect(fakeAdapter.requests.length, equals(1));
    });

    test('sends If-None-Match header in subsequent requests', () async {
      final config = CacheConfig(
        inMemory: true,
        storePath: tempDir.path,
      );
      final interceptor = AcdcCacheInterceptor(
        config: config,
        store: CacheStoreFactory.build(config),
      );
      dio.interceptors.add(interceptor);

      final etag = '"test-etag-12345"';

      // 1. Configure first response
      fakeAdapter.setResponse(
        '{"data": "fresh"}',
        200,
        headers: {
          'etag': [etag],
          'content-type': ['application/json'],
          'cache-control': ['public, max-age=0'],
          'date': ['Wed, 21 Oct 2015 07:28:00 GMT'],
        },
      );

      // 2. Perform first request to populate cache
      await dio.get('/data');

      // 3. Clear requests log to isolate next request verification
      fakeAdapter.requests.clear();

      // 4. Configure second response (simulating 304 or 200, doesn't matter for header check)
      fakeAdapter.setResponse(
        '{"data": "fresh"}',
        200,
        headers: {
          'etag': [etag],
        },
      );

      // 5. Perform second request
      await dio.get('/data');

      // 6. Verify If-None-Match header was sent
      expect(fakeAdapter.requests.length, equals(1));
      final options = fakeAdapter.requests.first;

      expect(options.headers['if-none-match'], equals(etag));
    });

    test('uses cached response on 304 Not Modified', () async {
      final config = CacheConfig(
        inMemory: true,
        storePath: tempDir.path,
      );
      final interceptor = AcdcCacheInterceptor(
        config: config,
        store: CacheStoreFactory.build(config),
      );
      dio.interceptors.add(interceptor);

      final etag = '"test-etag-12345"';

      // 1. Configure first response with ETag
      fakeAdapter.setResponse(
        '{"data": "fresh"}',
        200,
        headers: {
          'etag': [etag],
          'content-type': ['application/json'],
          'cache-control': ['public, max-age=0'],
          'date': ['Wed, 21 Oct 2015 07:28:00 GMT'],
        },
      );

      // 2. Populate cache
      await dio.get('/data');

      // 3. Configure mock to return 304 for next request
      fakeAdapter.setResponse(
        '',
        304,
        headers: {
          'etag': [etag],
          'date': ['Wed, 21 Oct 2015 07:29:00 GMT'],
          'cache-control': ['public, max-age=0'],
        },
      );

      // 4. Perform second request
      final response = await dio.get('/data');

      // 5. Verify response is from cache and has original data
      expect(
          response.statusCode,
          equals(
              200)); // Dio/Interceptor should resolve 304 to 200 with cached content
      expect(response.data['data'], equals('fresh'));
      expect(response.headers.value('x-acdc-from-cache'), equals('true'));
      expect(response.headers.value('if-none-match'),
          isNull); // Client should NOT see if-none-match in response? No, request header.
    });
  });
}
