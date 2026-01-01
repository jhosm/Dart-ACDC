import 'package:dart_acdc/src/exceptions/acdc_auth_exception.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  group('AcdcAuthException', () {
    test('fromDioException handles 401 responses', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 401,
          data: {'error': 'Unauthorized'},
        ),
      );

      final exception = AcdcAuthException.fromDioException(dioException);

      expect(exception.statusCode, equals(401));
      expect(exception.message, contains('Invalid or expired token'));
    });

    test('fromDioException handles 403 responses', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 403,
          data: {'error': 'Forbidden'},
        ),
      );

      final exception = AcdcAuthException.fromDioException(dioException);

      expect(exception.statusCode, equals(403));
      expect(exception.message, contains('Insufficient permissions'));
    });

    test('fromDioException truncates response body', () {
      final longBody = 'a' * 2000;
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 401,
          data: longBody,
        ),
      );

      final exception = AcdcAuthException.fromDioException(dioException);

      expect(exception.responseData, isNotNull);
      expect(
        exception.responseData.toString().length,
        lessThan(1100),
      );
    });

    test('fromDioException redacts sensitive URL parameters', () {
      final dioException = DioException(
        requestOptions: RequestOptions(
          path: '/test',
          queryParameters: {'token': 'secret123'},
        ),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 401,
        ),
      );

      final exception = AcdcAuthException.fromDioException(dioException);

      expect(exception.requestUrl, isNotNull);
      // URL encoding may encode the asterisks
      expect(
        exception.requestUrl,
        anyOf(contains('***REDACTED***'), contains('REDACTED')),
      );
      expect(exception.requestUrl, isNot(contains('secret123')));
    });
  });
}
