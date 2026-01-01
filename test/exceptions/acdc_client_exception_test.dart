import 'package:dart_acdc/src/exceptions/acdc_client_exception.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  group('AcdcClientException', () {
    test('fromDioException handles 400 Bad Request', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 400,
        ),
      );

      final exception = AcdcClientException.fromDioException(dioException);

      expect(exception.statusCode, equals(400));
      expect(exception.message, contains('Bad Request'));
      expect(exception.message, contains('Invalid request parameters'));
    });

    test('fromDioException handles 404 Not Found', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 404,
        ),
      );

      final exception = AcdcClientException.fromDioException(dioException);

      expect(exception.statusCode, equals(404));
      expect(exception.message, contains('Not Found'));
      expect(exception.message, contains('does not exist'));
    });

    test('fromDioException handles 422 Unprocessable Entity', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 422,
        ),
      );

      final exception = AcdcClientException.fromDioException(dioException);

      expect(exception.statusCode, equals(422));
      expect(exception.message, contains('Unprocessable Entity'));
      expect(exception.message, contains('Validation failed'));
    });

    test('fromDioException handles 429 with Retry-After header (seconds)', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 429,
          headers: Headers.fromMap({
            'retry-after': ['60'],
          }),
        ),
      );

      final exception = AcdcClientException.fromDioException(dioException);

      expect(exception.statusCode, equals(429));
      expect(exception.message, contains('Too Many Requests'));
      expect(exception.message, contains('Retry after 60 seconds'));
      expect(exception.retryAfter, equals(const Duration(seconds: 60)));
    });

    test('fromDioException handles 429 without Retry-After header', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 429,
        ),
      );

      final exception = AcdcClientException.fromDioException(dioException);

      expect(exception.statusCode, equals(429));
      expect(exception.retryAfter, isNull);
    });

    test('toMap includes retryAfter duration', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 429,
          headers: Headers.fromMap({
            'retry-after': ['30'],
          }),
        ),
      );

      final exception = AcdcClientException.fromDioException(dioException);
      final map = exception.toMap();

      expect(map['retryAfter'], equals(30));
    });
  });
}
