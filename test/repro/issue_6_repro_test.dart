import 'dart:typed_data';

import 'package:dart_acdc/dart_acdc.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:test/test.dart';

void main() {
  group('Issue #6 Repro: Cache Logging in Builder', () {
    late MockLogDelegate logDelegate;

    setUp(() {
      logDelegate = MockLogDelegate();
    });

    test('repro: cache logs are missing when built via AcdcClientBuilder',
        () async {
      // 1. Build client with cache and log delegate
      // Disable auth to avoid Flutter Secure Storage platform channel issues
      final dio = await const AcdcClientBuilder()
          .withBaseUrl('https://api.example.com')
          .withCache(const CacheConfig())
          .withCacheStore(MemCacheStore())
          .withLogDelegate(logDelegate)
          .withNetworkInfo(MockNetworkInfo())
          .withLogLevel(LogLevel.info)
          .disableAuth()
          .build();

      // Mock Adapter to serve response
      dio.httpClientAdapter = MockAdapter((options) async => ResponseBody.fromString(
          '{}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'cache-control': ['max-age=3600'],
          },
        ),);

      // 2. Make a request (Should invoke Cache Miss / Write)
      await dio.get<dynamic>('/test');

      // 3. Verify logs - EXPECTED BEHAVIOR (Should have cache miss/write)
      final logs = logDelegate.logs;

      expect(
        logs.any((l) => l['metadata']['type'] == 'cache_miss'),
        isTrue,
        reason: 'Cache Miss log should be present',
      );

      expect(
        logs.any((l) => l['metadata']['type'] == 'cache_write'),
        isTrue,
        reason: 'Cache Write log should be present',
      );
    });
  });
}

// Minimal mocks for repro
class MockNetworkInfo implements NetworkInfo {
  @override
  bool get isConnected => true;

  @override
  Stream<NetworkStatus> get onStatusChange => const Stream.empty();

  @override
  void dispose() {}
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
