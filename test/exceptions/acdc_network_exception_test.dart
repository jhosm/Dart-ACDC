import 'package:dart_acdc/src/exceptions/acdc_network_exception.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  group('AcdcNetworkException', () {
    test('fromDioException maps connection timeout correctly', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      );

      final exception = AcdcNetworkException.fromDioException(dioException);

      expect(
        exception.networkErrorType,
        equals(NetworkErrorType.connectionTimeout),
      );
      expect(exception.message, contains('Connection timeout'));
    });

    test('fromDioException maps send timeout correctly', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.sendTimeout,
      );

      final exception = AcdcNetworkException.fromDioException(dioException);

      expect(exception.networkErrorType, equals(NetworkErrorType.sendTimeout));
      expect(exception.message, contains('Send timeout'));
    });

    test('fromDioException maps receive timeout correctly', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.receiveTimeout,
      );

      final exception = AcdcNetworkException.fromDioException(dioException);

      expect(
        exception.networkErrorType,
        equals(NetworkErrorType.receiveTimeout),
      );
      expect(exception.message, contains('Receive timeout'));
    });

    test('fromDioException maps cancelled requests correctly', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.cancel,
      );

      final exception = AcdcNetworkException.fromDioException(dioException);

      expect(exception.networkErrorType, equals(NetworkErrorType.cancelled));
      expect(exception.message, contains('cancelled'));
    });

    test('fromDioException maps connection errors correctly', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionError,
      );

      final exception = AcdcNetworkException.fromDioException(dioException);

      expect(
        exception.networkErrorType,
        equals(NetworkErrorType.noConnection),
      );
      expect(exception.message, contains('No internet connection'));
    });

    test('toMap includes network error type', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      );

      final exception = AcdcNetworkException.fromDioException(dioException);
      final map = exception.toMap();

      expect(map['networkErrorType'], equals('connectionTimeout'));
    });
  });
}
