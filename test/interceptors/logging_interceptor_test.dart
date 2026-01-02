import 'package:dart_acdc/src/interceptors/logging_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  group('LoggingInterceptor Redaction', () {
    late LoggingInterceptor interceptor;
    late List<Map<String, dynamic>> logs;

    setUp(() {
      logs = [];
      interceptor = LoggingInterceptor(
        logger: (message, level, metadata) {
          if (metadata != null) {
            logs.add(metadata);
          }
        },
        sensitiveFields: ['password', 'token', 'secret', 'authorization'],
      );
    });

    test('redacts sensitive headers', () {
      final options = RequestOptions(
        path: '/test',
        headers: {
          'Authorization': 'Bearer 12345',
          'X-Secret-Token': 'secret_value',
          'Content-Type': 'application/json',
        },
      );
      final handler = RequestInterceptorHandler();

      interceptor.onRequest(options, handler);

      expect(logs.length, 1);
      final headers = logs.first['headers'] as Map;
      expect(headers['Authorization'], '[REDACTED]');
      // Note: 'X-Secret-Token' matches 'token' so it should be redacted
      expect(headers['X-Secret-Token'], '[REDACTED]');
      expect(headers['Content-Type'], 'application/json');
    });

    test('redacts sensitive body fields (Map)', () {
      final options = RequestOptions(
        path: '/test',
        data: {
          'username': 'user',
          'password': 'my_password',
          'nested': {'accessToken': 'xyz', 'publicInfo': 'visible'},
        },
      );
      final handler = RequestInterceptorHandler();

      interceptor.onRequest(options, handler);

      expect(logs.length, 1);
      final body = logs.first['body'] as Map;
      expect(body['password'], '[REDACTED]');
      final nested = body['nested'] as Map;
      expect(nested['accessToken'], '[REDACTED]');
      expect(body['username'], 'user');
      expect(nested['publicInfo'], 'visible');
    });

    test('redacts sensitive body fields (JSON String)', () {
      final options = RequestOptions(
        path: '/test',
        data: '{"password": "secret", "other": "value"}',
      );
      final handler = RequestInterceptorHandler();

      interceptor.onRequest(options, handler);

      expect(logs.length, 1);
      final body = logs.first['body'] as Map;
      expect(body['password'], '[REDACTED]');
      expect(body['other'], 'value');
    });

    test('redacts partial matches in keys', () {
      // "client_secret" contains "secret"
      final options = RequestOptions(
        path: '/test',
        data: {'client_secret': '123'},
      );
      interceptor.onRequest(options, RequestInterceptorHandler());
      final body = logs.first['body'] as Map;
      expect(body['client_secret'], '[REDACTED]');
    });
  });

  group('LoggingInterceptor Resilience', () {
    test('proceeds when logger throws exception', () {
      final interceptor = LoggingInterceptor(
        logger: (message, level, metadata) {
          throw Exception('Logger failed');
        },
      );

      final options = RequestOptions(path: '/test');
      final handler = _FakeRequestHandler();

      // Should not throw
      interceptor.onRequest(options, handler);

      expect(
        handler.nextCalled,
        isTrue,
        reason: 'handler.next should be called even if logger fails',
      );
    });
  });
}

class _FakeRequestHandler extends RequestInterceptorHandler {
  bool nextCalled = false;

  @override
  void next(RequestOptions requestOptions) {
    nextCalled = true;
  }
}
