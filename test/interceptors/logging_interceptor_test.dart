import 'package:dart_acdc/src/interceptors/logging_interceptor.dart';
import 'package:dart_acdc/src/logging/acdc_log_delegate.dart';
import 'package:dart_acdc/src/logging/log_level.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  group('LoggingInterceptor Redaction', () {
    late LoggingInterceptor interceptor;
    late List<Map<String, dynamic>> logs;

    setUp(() {
      logs = [];
      interceptor = LoggingInterceptor(
        logDelegate: _MockLogDelegate((message, level, metadata) {
          logs.add(metadata);
        }),
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
        logDelegate: _MockLogDelegate((message, level, metadata) {
          throw Exception('Logger failed');
        }),
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

    test('prevents circular logging dependencies', () {
      var logCount = 0;
      late LoggingInterceptor interceptor;

      interceptor = LoggingInterceptor(
        logDelegate: _MockLogDelegate((message, level, metadata) {
          logCount++;
          // Simulate circular dependency by trying to log again
          if (logCount == 1) {
            // This would cause a circular dependency
            // The _safeLog method should detect and prevent it
            final nestedOptions = RequestOptions(path: '/nested');
            interceptor.onRequest(nestedOptions, _FakeRequestHandler());
          }
        }),
      );

      final options = RequestOptions(path: '/test');
      interceptor.onRequest(options, _FakeRequestHandler());

      // Should only log once, not recursively
      expect(logCount, 1, reason: 'Should prevent circular logging');
    });

    test('handles logger exception in onResponse', () {
      final interceptor = LoggingInterceptor(
        logDelegate: _MockLogDelegate((message, level, metadata) {
          throw Exception('Response logger failed');
        }),
      );

      final options = RequestOptions(path: '/test');
      options.extra['acdc_request_start_time'] =
          DateTime.now().millisecondsSinceEpoch;

      final response = Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
      );

      final handler = _FakeResponseHandler();

      // Should not throw
      interceptor.onResponse(response, handler);

      expect(
        handler.nextCalled,
        isTrue,
        reason: 'handler.next should be called even if logger fails',
      );
    });

    test('handles logger exception in onError', () {
      final interceptor = LoggingInterceptor(
        logDelegate: _MockLogDelegate((message, level, metadata) {
          throw Exception('Error logger failed');
        }),
      );

      final options = RequestOptions(path: '/test');
      final err = DioException.connectionTimeout(
        requestOptions: options,
        timeout: const Duration(seconds: 5),
      );

      final handler = _FakeErrorHandler();

      // Should not throw
      interceptor.onError(err, handler);

      expect(
        handler.nextCalled,
        isTrue,
        reason: 'handler.next should be called even if logger fails',
      );
    });

    test('handles exception during body redaction', () {
      final interceptor = LoggingInterceptor(
        logDelegate: _MockLogDelegate((message, level, metadata) {
          // Logger is called, just capture it
        }),
      );

      // Create data that might cause issues during serialization
      final options = RequestOptions(
        path: '/test',
        data: _CircularReference(),
      );

      final handler = _FakeRequestHandler();

      // Should not throw even with problematic data
      expect(() => interceptor.onRequest(options, handler), returnsNormally);
      expect(handler.nextCalled, isTrue);
    });
  });

  group('LoggingInterceptor Slow Request Warning', () {
    late LoggingInterceptor interceptor;
    late List<Map<String, dynamic>> logs;

    setUp(() {
      logs = [];
      interceptor = LoggingInterceptor(
        logDelegate: _MockLogDelegate((message, level, metadata) {
          if (metadata['type'] == 'slow_request') {
            logs.add(metadata);
          }
        }),
        slowRequestThreshold: const Duration(milliseconds: 100),
      );
    });

    test('logs warning when request exceeds threshold', () {
      final options = RequestOptions(path: '/test');
      // Simulate slow request by setting start time in the past
      options.extra['acdc_request_start_time'] =
          DateTime.now().millisecondsSinceEpoch - 200;

      final response = Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
      );

      interceptor.onResponse(response, ResponseInterceptorHandler());

      expect(logs.length, 1);
      expect(logs.first['type'], 'slow_request');
      expect(logs.first['duration_ms'], greaterThan(100));
    });

    test('does not log when request is fast', () {
      final options = RequestOptions(path: '/test');
      options.extra['acdc_request_start_time'] =
          DateTime.now().millisecondsSinceEpoch - 50;

      final response = Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
      );

      interceptor.onResponse(response, ResponseInterceptorHandler());

      expect(logs.length, 0);
    });
  });

  group('LoggingInterceptor Large Payload Warning', () {
    late List<Map<String, dynamic>> logs;

    test('logs warning for large request payload', () {
      logs = [];
      final interceptor = LoggingInterceptor(
        logDelegate: _MockLogDelegate((message, level, metadata) {
          if (metadata['type'] == 'large_payload') {
            logs.add(metadata);
          }
        }),
        largePayloadThreshold: 100, // 100 bytes threshold
      );

      // Create payload > 100 bytes
      final largeData = {'data': 'x' * 200};
      final options = RequestOptions(path: '/test', data: largeData);

      interceptor.onRequest(options, RequestInterceptorHandler());

      expect(logs.length, 1);
      expect(logs.first['type'], 'large_payload');
      expect(logs.first['payload_type'], 'request');
      expect(logs.first['size_bytes'], greaterThan(100));
    });

    test('logs warning for large response payload', () {
      logs = [];
      final interceptor = LoggingInterceptor(
        logDelegate: _MockLogDelegate((message, level, metadata) {
          if (metadata['type'] == 'large_payload') {
            logs.add(metadata);
          }
        }),
        largePayloadThreshold: 100, // 100 bytes threshold
      );

      final options = RequestOptions(path: '/test');
      options.extra['acdc_request_start_time'] =
          DateTime.now().millisecondsSinceEpoch;

      // Create large response
      final largeData = {'data': 'x' * 200};
      final response = Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: largeData,
      );

      interceptor.onResponse(response, ResponseInterceptorHandler());

      expect(logs.length, 1);
      expect(logs.first['type'], 'large_payload');
      expect(logs.first['payload_type'], 'response');
    });
  });

  group('LoggingInterceptor Enhanced Error Logging', () {
    late List<Map<String, dynamic>> logs;
    late LoggingInterceptor interceptor;

    setUp(() {
      logs = [];
      interceptor = LoggingInterceptor(
        logDelegate: _MockLogDelegate((message, level, metadata) {
          if (metadata['type'] == 'error') {
            logs.add(metadata);
          }
        }),
      );
    });

    test('logs connection timeout with details', () {
      final options = RequestOptions(path: '/test');
      final err = DioException.connectionTimeout(
        requestOptions: options,
        timeout: const Duration(seconds: 5),
      );

      interceptor.onError(err, _FakeErrorHandler());

      expect(logs.length, 1);
      expect(logs.first['error_type'], 'connection_timeout');
      expect(logs.first['timeout_type'], 'Connection establishment');
    });

    test('logs SSL certificate error', () {
      final options = RequestOptions(path: '/test');
      final err = DioException.badCertificate(
        requestOptions: options,
      );

      interceptor.onError(err, _FakeErrorHandler());

      expect(logs.length, 1);
      expect(logs.first['error_type'], 'ssl_certificate_error');
    });

    test('logs HTTP 4xx as warning level', () {
      final options = RequestOptions(path: '/test');
      final response = Response<dynamic>(
        requestOptions: options,
        statusCode: 404,
      );
      final err = DioException.badResponse(
        requestOptions: options,
        response: response,
        statusCode: 404,
      );

      var capturedLevel = LogLevel.info;
      LoggingInterceptor(
        logDelegate: _MockLogDelegate((message, level, metadata) {
          capturedLevel = level;
        }),
      ).onError(err, _FakeErrorHandler());

      expect(capturedLevel, LogLevel.warning);
    });

    test('logs HTTP 5xx as error level', () {
      final options = RequestOptions(path: '/test');
      final response = Response<dynamic>(
        requestOptions: options,
        statusCode: 500,
      );
      final err = DioException.badResponse(
        requestOptions: options,
        response: response,
        statusCode: 500,
      );

      var capturedLevel = LogLevel.info;
      LoggingInterceptor(
        logDelegate: _MockLogDelegate((message, level, metadata) {
          capturedLevel = level;
        }),
      ).onError(err, _FakeErrorHandler());

      expect(capturedLevel, LogLevel.error);
    });

    test('logs request cancellation as info level', () {
      final options = RequestOptions(path: '/test');
      final err = DioException.requestCancelled(
        requestOptions: options,
        reason: 'Manual cancellation',
      );

      var capturedLevel = LogLevel.error;
      LoggingInterceptor(
        logDelegate: _MockLogDelegate((message, level, metadata) {
          capturedLevel = level;
        }),
      ).onError(err, _FakeErrorHandler());

      expect(capturedLevel, LogLevel.info);
    });

    test('logs send timeout', () {
      final options = RequestOptions(path: '/test');
      final err = DioException.sendTimeout(
        requestOptions: options,
        timeout: const Duration(seconds: 5),
      );

      interceptor.onError(err, _FakeErrorHandler());

      expect(logs.length, 1);
      final metadata = logs.first;
      expect(metadata['error_type'], 'send_timeout');
    });

    test('logs receive timeout', () {
      final options = RequestOptions(path: '/test');
      final err = DioException.receiveTimeout(
        requestOptions: options,
        timeout: const Duration(seconds: 5),
      );

      interceptor.onError(err, _FakeErrorHandler());

      expect(logs.length, 1);
      final metadata = logs.first;
      expect(metadata['error_type'], 'receive_timeout');
    });

    test('logs unknown error', () {
      final options = RequestOptions(path: '/test');
      final err = DioException.connectionError(
        requestOptions: options,
        reason: 'Unknown',
        error: 'Unknown',
      );

      interceptor.onError(err, _FakeErrorHandler());

      expect(logs.length, 1);
      final metadata = logs.first;
      expect(metadata['error_type'], 'network_error');
    });
  });

  group('LoggingInterceptor Print Logs', () {
    test('prints request logs to console', () {
      final interceptor = LoggingInterceptor(
        printLogs: true,
      );

      final options = RequestOptions(
        path: '/test',
        data: {'key': 'value'},
        headers: {'header': 'value'},
      );

      // We can't easily assert print output in unit tests without Zone interception
      // But we can ensure it doesn't throw
      expect(
        () => interceptor.onRequest(options, RequestInterceptorHandler()),
        returnsNormally,
      );
    });

    test('prints response logs to console', () {
      final interceptor = LoggingInterceptor(
        printLogs: true,
      );

      final response = Response<dynamic>(
        requestOptions: RequestOptions(path: '/test'),
        statusCode: 200,
        data: {'key': 'value'},
        headers: Headers.fromMap({
          'header': ['value'],
        }),
      );

      expect(
        () => interceptor.onResponse(response, ResponseInterceptorHandler()),
        returnsNormally,
      );
    });

    test('prints error logs to console', () {
      final interceptor = LoggingInterceptor(
        printLogs: true,
      );

      final err = DioException.connectionTimeout(
        requestOptions: RequestOptions(path: '/test'),
        timeout: const Duration(seconds: 1),
      );

      expect(
        () => interceptor.onError(err, _FakeErrorHandler()),
        returnsNormally,
      );
    });
    test('prints safeLog fallback to console', () {
      final interceptor = LoggingInterceptor(
        printLogs: true,
        logDelegate: _MockLogDelegate((message, level, metadata) {
          throw Exception('Logger failed');
        }),
      );

      final options = RequestOptions(path: '/test');

      expect(
        () => interceptor.onRequest(options, RequestInterceptorHandler()),
        returnsNormally,
      );
    });
  });
}

class _MockLogDelegate implements AcdcLogDelegate {
  _MockLogDelegate(this.onLog);
  final void Function(String, LogLevel, Map<String, dynamic>) onLog;
  @override
  void log(String message, LogLevel level, Map<String, dynamic> metadata) =>
      onLog(message, level, metadata);
}

class _FakeRequestHandler extends RequestInterceptorHandler {
  bool nextCalled = false;

  @override
  void next(RequestOptions requestOptions) {
    nextCalled = true;
  }
}

class _FakeResponseHandler extends ResponseInterceptorHandler {
  bool nextCalled = false;

  @override
  void next(Response<dynamic> response) {
    nextCalled = true;
  }
}

class _FakeErrorHandler extends ErrorInterceptorHandler {
  bool nextCalled = false;

  @override
  void next(DioException err) {
    nextCalled = true;
  }
}

class _CircularReference {
  _CircularReference() {
    self = this;
  }

  late _CircularReference self;
}
