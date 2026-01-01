import 'package:dart_acdc/src/exceptions/acdc_auth_exception.dart';
import 'package:dart_acdc/src/exceptions/acdc_client_exception.dart';
import 'package:dart_acdc/src/exceptions/acdc_network_exception.dart';
import 'package:dart_acdc/src/exceptions/acdc_server_exception.dart';
import 'package:dart_acdc/src/interceptors/error_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

/// Test helper for ErrorInterceptorHandler
class TestErrorInterceptorHandler extends ErrorInterceptorHandler {
  DioException? capturedError;

  @override
  void next(DioException err) {
    capturedError = err;
  }
}

void main() {
  group('ErrorInterceptor', () {
    late ErrorInterceptor interceptor;

    setUp(() {
      interceptor = const ErrorInterceptor();
    });

    test('converts 401 response to AcdcAuthException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 401,
        ),
      );

      final handler = TestErrorInterceptorHandler();
      interceptor.onError(dioException, handler);

      expect(handler.capturedError, isA<AcdcAuthException>());
      expect(
        (handler.capturedError! as AcdcAuthException).statusCode,
        equals(401),
      );
    });

    test('converts 403 response to AcdcAuthException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 403,
        ),
      );

      final handler = TestErrorInterceptorHandler();
      interceptor.onError(dioException, handler);

      expect(handler.capturedError, isA<AcdcAuthException>());
      expect(
        (handler.capturedError! as AcdcAuthException).statusCode,
        equals(403),
      );
    });

    test('converts 4xx responses to AcdcClientException', () {
      for (final statusCode in [400, 404, 422, 429]) {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/test'),
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: statusCode,
          ),
        );

        final handler = TestErrorInterceptorHandler();
        interceptor.onError(dioException, handler);

        expect(handler.capturedError, isA<AcdcClientException>());
        expect(
          (handler.capturedError! as AcdcClientException).statusCode,
          equals(statusCode),
        );
      }
    });

    test('converts 5xx responses to AcdcServerException', () {
      for (final statusCode in [500, 502, 503, 504]) {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/test'),
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: statusCode,
          ),
        );

        final handler = TestErrorInterceptorHandler();
        interceptor.onError(dioException, handler);

        expect(handler.capturedError, isA<AcdcServerException>());
        expect(
          (handler.capturedError! as AcdcServerException).statusCode,
          equals(statusCode),
        );
      }
    });

    test('converts connection timeout to AcdcNetworkException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      );

      final handler = TestErrorInterceptorHandler();
      interceptor.onError(dioException, handler);

      expect(handler.capturedError, isA<AcdcNetworkException>());
      expect(
        (handler.capturedError! as AcdcNetworkException).networkErrorType,
        equals(NetworkErrorType.connectionTimeout),
      );
    });

    test('converts send timeout to AcdcNetworkException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.sendTimeout,
      );

      final handler = TestErrorInterceptorHandler();
      interceptor.onError(dioException, handler);

      expect(handler.capturedError, isA<AcdcNetworkException>());
      expect(
        (handler.capturedError! as AcdcNetworkException).networkErrorType,
        equals(NetworkErrorType.sendTimeout),
      );
    });

    test('converts receive timeout to AcdcNetworkException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.receiveTimeout,
      );

      final handler = TestErrorInterceptorHandler();
      interceptor.onError(dioException, handler);

      expect(handler.capturedError, isA<AcdcNetworkException>());
      expect(
        (handler.capturedError! as AcdcNetworkException).networkErrorType,
        equals(NetworkErrorType.receiveTimeout),
      );
    });

    test('converts connection errors to AcdcNetworkException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionError,
      );

      final handler = TestErrorInterceptorHandler();
      interceptor.onError(dioException, handler);

      expect(handler.capturedError, isA<AcdcNetworkException>());
      expect(
        (handler.capturedError! as AcdcNetworkException).networkErrorType,
        equals(NetworkErrorType.noConnection),
      );
    });

    test('converts cancelled requests to AcdcNetworkException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.cancel,
      );

      final handler = TestErrorInterceptorHandler();
      interceptor.onError(dioException, handler);

      expect(handler.capturedError, isA<AcdcNetworkException>());
      expect(
        (handler.capturedError! as AcdcNetworkException).networkErrorType,
        equals(NetworkErrorType.cancelled),
      );
    });
  });
}
