import 'package:dart_acdc/src/logging/acdc_logger.dart';
import 'package:dart_acdc/src/logging/log_level.dart';
import 'package:dio/dio.dart';

/// Interceptor that handles logging of requests, responses, and errors.
class LoggingInterceptor extends Interceptor {
  /// Creates a new [LoggingInterceptor].
  const LoggingInterceptor({
    required this.level,
    this.logger,
  });

  /// The log verbosity level.
  final LogLevel level;

  /// Custom logger function.
  final AcdcLogger? logger;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (level == LogLevel.none) {
      return handler.next(options);
    }

    if (logger != null) {
      // Basic info logging
      if (level.index <= LogLevel.info.index) {
        logger!(
          'Request: ${options.method} ${options.uri}',
          LogLevel.info,
          {'headers': options.headers, 'data': options.data},
        );
      } else if (level == LogLevel.debug) {
        logger!(
          'Request: ${options.method} ${options.uri}',
          LogLevel.debug,
          {'headers': options.headers, 'data': options.data},
        );
      }
    }

    super.onRequest(options, handler);
  }

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler,) {
    if (level == LogLevel.none) {
      return handler.next(response);
    }

    if (logger != null) {
      if (level.index <= LogLevel.info.index) {
        logger!(
          'Response: ${response.statusCode} ${response.realUri}',
          LogLevel.info,
          {'data': response.data},
        );
      }
    }

    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (level == LogLevel.none) {
      return handler.next(err);
    }

    if (logger != null) {
      // Errors are always logged unless level is none
      logger!(
        'Error: ${err.response?.statusCode} ${err.requestOptions.uri}',
        LogLevel.error,
        {'error': err.error, 'message': err.message},
      );
    }

    super.onError(err, handler);
  }
}
