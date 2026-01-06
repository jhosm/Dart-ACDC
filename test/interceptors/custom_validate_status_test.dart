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

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel,
            (MethodCall methodCall) async {
      return null;
    });
  });

  group('AcdcCacheInterceptor Custom ValidateStatus', () {
    late Dio dio;
    late FakeHttpClientAdapter fakeAdapter;
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('acdc_test_custom_');
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

    test('handles 304 when validateStatus allows it', () async {
      final config = CacheConfig(
        inMemory: true,
        storePath: tempDir.path,
      );
      final interceptor = AcdcCacheInterceptor(
        config: config,
        store: CacheStoreFactory.build(config),
      );
      dio.interceptors.add(interceptor);

      // Allow 304 as specific success status
      dio.options.validateStatus = (status) {
        return status != null &&
            (status >= 200 && status < 300 || status == 304);
      };

      final etag = '"test-etag-12345"';

      // 1. Initial request to populate cache
      fakeAdapter.setResponse(
        '{"data": "fresh"}',
        200,
        headers: {
          'etag': [etag],
          'content-type': ['application/json'],
          'cache-control': ['public, max-age=0'],
        },
      );
      await dio.get('/data');

      // 2. Second request returns 304
      fakeAdapter.setResponse(
        '',
        304,
        headers: {
          'etag': [etag],
          'cache-control': ['public, max-age=0'],
        },
      );

      // 3. Perform request
      final response = await dio.get('/data');

      // 4. Verification
      expect(response.statusCode, equals(200),
          reason: 'Should resolve 304 to 200 with cached content');
      expect(response.data['data'], equals('fresh'),
          reason: 'Should return cached data');
      expect(response.headers.value('x-acdc-from-cache'), equals('true'));
    });
  });
}
