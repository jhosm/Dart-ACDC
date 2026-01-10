import 'package:dart_acdc/src/exceptions/acdc_exception.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  group('AcdcException', () {
    test('truncateResponseBody truncates long responses', () {
      final longBody = 'a' * 2000;
      final truncated = AcdcException.truncateResponseBody(longBody);

      expect(truncated, isNotNull);
      expect(truncated!.length, equals(1024 + '... (truncated)'.length));
      expect(truncated, endsWith('... (truncated)'));
    });

    test('truncateResponseBody preserves short responses', () {
      const shortBody = 'short response';
      final result = AcdcException.truncateResponseBody(shortBody);

      expect(result, equals(shortBody));
    });

    test('truncateResponseBody handles null', () {
      final result = AcdcException.truncateResponseBody(null);
      expect(result, isNull);
    });

    test('redactUrl redacts sensitive query parameters', () {
      const url = 'https://api.example.com/endpoint?'
          'token=secret123&name=john&api_key=key456';
      final redacted = AcdcException.redactUrl(url);

      // URL encoding may encode the asterisks
      expect(
        redacted,
        anyOf(contains('token=***REDACTED***'), contains('REDACTED')),
      );
      expect(
        redacted,
        anyOf(contains('api_key=***REDACTED***'), contains('REDACTED')),
      );
      expect(redacted, contains('name=john'));
      expect(redacted, isNot(contains('secret123')));
      expect(redacted, isNot(contains('key456')));
    });

    test('redactUrl handles URLs without query params', () {
      const url = 'https://api.example.com/endpoint';
      final redacted = AcdcException.redactUrl(url);

      expect(redacted, equals(url));
    });

    test('redactUrl handles invalid URLs', () {
      const url = 'not-a-valid-url';
      final redacted = AcdcException.redactUrl(url);

      expect(redacted, equals(url));
    });

    test('toMap includes all relevant fields', () {
      final exception = AcdcException(
        requestOptions: RequestOptions(path: '/test'),
        message: 'Test error',
        originalException: DioException(
          requestOptions: RequestOptions(path: '/test'),
        ),
        statusCode: 500,
        responseData: 'error data',
        requestUrl: 'https://api.example.com/test',
      );

      final map = exception.toMap();

      expect(map['type'], equals('AcdcException'));
      expect(map['message'], equals('Test error'));
      expect(map['statusCode'], equals(500));
      expect(map['requestUrl'], equals('https://api.example.com/test'));
      expect(map['responseData'], equals('error data'));
      expect(map['originalError'], isNotNull);
    });

    test('toString includes status code and URL', () {
      final exception = AcdcException(
        requestOptions: RequestOptions(path: '/test'),
        message: 'Test error',
        originalException: DioException(
          requestOptions: RequestOptions(path: '/test'),
        ),
        statusCode: 404,
        requestUrl: 'https://api.example.com/test',
      );

      final str = exception.toString();

      expect(str, contains('Test error'));
      expect(str, contains('HTTP 404'));
      expect(str, contains('https://api.example.com/test'));
    });
  });
}
