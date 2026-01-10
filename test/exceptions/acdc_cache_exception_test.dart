import 'package:dart_acdc/dart_acdc.dart';
import 'package:dart_acdc/src/exceptions/acdc_cache_exception.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  group('AcdcCacheException', () {
    final requestOptions = RequestOptions(path: '/test');
    final stackTrace = StackTrace.current;
    final error = 'Cache error';

    test('constructor sets properties correctly', () {
      final exception = AcdcCacheException(
        requestOptions: requestOptions,
        message: 'Cache error',
        originalException: DioException(requestOptions: requestOptions),
        cacheOperation: CacheOperation.other,
        error: error,
        stackTrace: stackTrace,
      );

      expect(exception.requestOptions, requestOptions);
      expect(exception.message, 'Cache error');
      expect(exception.cacheOperation, CacheOperation.other);
      expect(exception.error, error);
      expect(exception.stackTrace, stackTrace);
      expect(exception.type, DioExceptionType.unknown);
    });

    test('initializationFailed factory creates correct exception', () {
      final exception = AcdcCacheException.initializationFailed(
        requestOptions: requestOptions,
        error: error,
        stackTrace: stackTrace,
      );

      expect(exception.requestOptions, requestOptions);
      expect(exception.message, contains('Cache initialization failed'));
      expect(exception.cacheOperation, CacheOperation.initialization);
      expect(exception.error, error);
      expect(exception.stackTrace, stackTrace);
    });

    test('readFailed factory creates correct exception', () {
      final exception = AcdcCacheException.readFailed(
        requestOptions: requestOptions,
        error: error,
        stackTrace: stackTrace,
      );

      expect(exception.requestOptions, requestOptions);
      expect(exception.message, contains('Cache read failed'));
      expect(exception.cacheOperation, CacheOperation.read);
      expect(exception.error, error);
      expect(exception.stackTrace, stackTrace);
    });

    test('writeFailed factory creates correct exception', () {
      final exception = AcdcCacheException.writeFailed(
        requestOptions: requestOptions,
        error: error,
        stackTrace: stackTrace,
      );

      expect(exception.requestOptions, requestOptions);
      expect(exception.message, contains('Cache write failed'));
      expect(exception.cacheOperation, CacheOperation.write);
      expect(exception.error, error);
      expect(exception.stackTrace, stackTrace);
    });

    test('clearFailed factory creates correct exception', () {
      final exception = AcdcCacheException.clearFailed(
        requestOptions: requestOptions,
        error: error,
        stackTrace: stackTrace,
      );

      expect(exception.requestOptions, requestOptions);
      expect(exception.message, contains('Cache clear failed'));
      expect(exception.cacheOperation, CacheOperation.clear);
      expect(exception.error, error);
      expect(exception.stackTrace, stackTrace);
    });

    test('toMap includes cacheOperation', () {
      final exception = AcdcCacheException(
        requestOptions: requestOptions,
        message: 'Cache error',
        originalException: DioException(requestOptions: requestOptions),
        cacheOperation: CacheOperation.read,
      );

      final map = exception.toMap();
      expect(map['cacheOperation'], 'read');
      expect(map['message'], 'Cache error');
    });
  });
}
