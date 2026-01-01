import 'package:dart_acdc/src/exceptions/acdc_exception.dart';
import 'package:dio/dio.dart';

/// Cache operation types for categorization.
enum CacheOperation {
  /// Cache read operation.
  read,

  /// Cache write operation.
  write,

  /// Cache initialization.
  initialization,

  /// Cache clear/invalidation.
  clear,

  /// Other cache operations.
  other,
}

/// Exception for cache-related errors.
///
/// Thrown when cache operations fail. These errors are typically non-fatal
/// and the library will fall back to fetching from the network.
class AcdcCacheException extends AcdcException {
  /// Creates a cache exception.
  AcdcCacheException({
    required super.requestOptions,
    required super.message,
    required super.originalException,
    required this.cacheOperation,
    super.error,
    super.stackTrace,
  }) : super(
          type: DioExceptionType.unknown,
        );

  /// Factory constructor for cache initialization failures.
  factory AcdcCacheException.initializationFailed({
    required RequestOptions requestOptions,
    required Object error,
    StackTrace? stackTrace,
  }) =>
      AcdcCacheException(
        requestOptions: requestOptions,
        message: 'Cache initialization failed: ${error.toString()}',
        originalException: DioException(
          requestOptions: requestOptions,
          error: error,
        ),
        cacheOperation: CacheOperation.initialization,
        error: error,
        stackTrace: stackTrace,
      );

  /// Factory constructor for cache read failures.
  factory AcdcCacheException.readFailed({
    required RequestOptions requestOptions,
    required Object error,
    StackTrace? stackTrace,
  }) =>
      AcdcCacheException(
        requestOptions: requestOptions,
        message: 'Cache read failed: ${error.toString()}',
        originalException: DioException(
          requestOptions: requestOptions,
          error: error,
        ),
        cacheOperation: CacheOperation.read,
        error: error,
        stackTrace: stackTrace,
      );

  /// Factory constructor for cache write failures.
  factory AcdcCacheException.writeFailed({
    required RequestOptions requestOptions,
    required Object error,
    StackTrace? stackTrace,
  }) =>
      AcdcCacheException(
        requestOptions: requestOptions,
        message: 'Cache write failed: ${error.toString()}',
        originalException: DioException(
          requestOptions: requestOptions,
          error: error,
        ),
        cacheOperation: CacheOperation.write,
        error: error,
        stackTrace: stackTrace,
      );

  /// Factory constructor for cache clear failures.
  factory AcdcCacheException.clearFailed({
    required RequestOptions requestOptions,
    required Object error,
    StackTrace? stackTrace,
  }) =>
      AcdcCacheException(
        requestOptions: requestOptions,
        message: 'Cache clear failed: ${error.toString()}',
        originalException: DioException(
          requestOptions: requestOptions,
          error: error,
        ),
        cacheOperation: CacheOperation.clear,
        error: error,
        stackTrace: stackTrace,
      );

  /// The cache operation that failed.
  final CacheOperation cacheOperation;

  @override
  Map<String, dynamic> toMap() => {
        ...super.toMap(),
        'cacheOperation': cacheOperation.name,
      };
}
