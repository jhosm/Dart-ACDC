import 'package:dart_acdc/src/exceptions/acdc_server_exception.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  group('AcdcServerException', () {
    test('fromDioException handles 500 Internal Server Error', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 500,
        ),
      );

      final exception = AcdcServerException.fromDioException(dioException);

      expect(exception.statusCode, equals(500));
      expect(exception.message, contains('Server error'));
      expect(exception.message, contains('HTTP 500'));
    });

    test('fromDioException handles 502 Bad Gateway', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 502,
        ),
      );

      final exception = AcdcServerException.fromDioException(dioException);

      expect(exception.statusCode, equals(502));
      expect(exception.message, contains('Server error'));
    });

    test('fromDioException handles 503 Service Unavailable', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 503,
        ),
      );

      final exception = AcdcServerException.fromDioException(dioException);

      expect(exception.statusCode, equals(503));
      expect(exception.message, contains('Server error'));
    });
  });
}
