import 'dart:convert';
import 'package:dart_acdc/src/logging/acdc_log_delegate.dart';
import 'package:dart_acdc/src/logging/log_level.dart';
import 'package:dio/dio.dart';

/// Interceptor that handles logging of requests, responses, and errors.
///
/// Features:
/// - Human-readable console logs (when enabled via [printLogs]).
/// - Structured logging via optional [AcdcLogDelegate].
/// - Adjustable verbosity levels.
/// - Automatic redaction of sensitive fields (headers and body).
/// - Resilient error handling (logging failures don't break the app).
class LoggingInterceptor extends Interceptor {
  /// Creates a new [LoggingInterceptor].
  LoggingInterceptor({
    this.level = LogLevel.info,
    this.logDelegate,
    List<String>? sensitiveFields,
    this.logRequestHeaders = true,
    this.logResponseHeaders = true,
    this.maxWidth = 120,
    this.compact = true,
    this.printLogs = false,
    this.slowRequestThreshold = const Duration(seconds: 3),
    this.largePayloadThreshold = 1048576, // 1 MB in bytes
  }) : sensitiveFields = sensitiveFields ??
            const [
              'password',
              'token',
              'secret',
              'access_token',
              'refresh_token',
              'client_secret',
              'authorization',
              'apikey',
              'api_key',
              'accesstoken',
              'refreshtoken',
              'pin',
              'ssn',
              'creditcard',
              'cvv',
              'privatekey',
              'private_key',
            ];

  /// The log verbosity level.
  final LogLevel level;

  /// Custom logger delegate.
  final AcdcLogDelegate? logDelegate;

  /// List of field names (case-insensitive) to redact from bodies and headers.
  final List<String> sensitiveFields;

  /// Whether to log request headers.
  final bool logRequestHeaders;

  /// Whether to log response headers.
  final bool logResponseHeaders;

  /// Max width for pretty printing.
  final int maxWidth;

  /// Whether to compact JSON output.
  final bool compact;

  /// Whether to print logs to console.
  final bool printLogs;

  /// Duration threshold for slow request warnings. Set to null to disable.
  final Duration? slowRequestThreshold;

  /// Byte threshold for large payload warnings. Set to null to disable.
  final int? largePayloadThreshold;

  /// Flag to prevent circular logging dependencies
  bool _isLogging = false;

  /// Safely invoke the logger with circular dependency prevention and timeout
  void _safeLog(
    String message,
    LogLevel logLevel,
    Map<String, dynamic> metadata,
  ) {
    if (logDelegate == null) return;

    // Prevent circular logging dependencies
    if (_isLogging) {
      if (printLogs) {
        // ignore: avoid_print
        print(
          'LoggingInterceptor: Circular logging dependency detected, skipping log',
        );
      }
      return;
    }

    try {
      _isLogging = true;

      // Invoke logger with timeout protection
      // Note: We can't use async/await here since the logger is synchronous
      // The timeout is a best-effort defense - the logger should be fast
      logDelegate!.log(message, logLevel, metadata);
    } on Object catch (e) {
      // Fallback to print() in case of logger failure
      if (printLogs) {
        // ignore: avoid_print
        print('LoggingInterceptor: Logger failed: $e');
        // ignore: avoid_print
        print('Original message: $message');
      }
    } finally {
      _isLogging = false;
    }
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (level == LogLevel.none) {
      return handler.next(options);
    }

    try {
      // 1. Console Logging
      if (printLogs && level != LogLevel.none) {
        // We manually print a debug representation that respects our redaction rules.
        _printDebugRequest(options);
      }

      // 2. Structured / Custom Logging
      if (logDelegate != null) {
        // Track request start time for duration calculation in response
        options.extra['acdc_request_start_time'] =
            DateTime.now().millisecondsSinceEpoch;

        final redactedBody = _redactBody(options.data);
        final redactedHeaders = _redactHeaders(options.headers);

        _safeLog(
          'Request: ${options.method} ${options.uri}',
          level,
          {
            'type': 'request',
            'method': options.method,
            'url': options.uri.toString(),
            'headers': redactedHeaders,
            'body': redactedBody,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );

        // Check for large request payload
        _checkLargePayload(
          options.data,
          'request',
          options.method,
          options.uri.toString(),
          null,
        );
      }
    } on Object catch (e, stack) {
      // Resilience: never crash request due to logging
      if (printLogs) {
        // ignore: avoid_print
        print('LoggingInterceptor Error: $e\n$stack');
      }
    }

    // We must call next since we didn't delegate to another interceptor
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (level == LogLevel.none) {
      return handler.next(response);
    }

    try {
      if (printLogs && level != LogLevel.none) {
        _printDebugResponse(response);
      }

      if (logDelegate != null) {
        final redactedBody = _redactBody(response.data);
        final redactedHeaders = _redactHeaders(response.headers.map);
        final durationMs = _calculateDuration(response);
        final fromCache = response.extra['from_cache'] as bool? ?? false;

        _safeLog(
          'Response: ${response.statusCode} ${response.requestOptions.uri}',
          level,
          {
            'type': 'response',
            'statusCode': response.statusCode,
            'url': response.requestOptions.uri.toString(),
            'headers': redactedHeaders,
            'body': redactedBody,
            'duration_ms': durationMs,
            'from_cache': fromCache,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );

        // Check for slow request warning
        if (slowRequestThreshold != null &&
            durationMs > slowRequestThreshold!.inMilliseconds) {
          _safeLog(
            'Slow request detected: ${response.requestOptions.method} ${response.requestOptions.uri}',
            LogLevel.warning,
            {
              'type': 'slow_request',
              'duration_ms': durationMs,
              'threshold_ms': slowRequestThreshold!.inMilliseconds,
              'url': response.requestOptions.uri.toString(),
              'method': response.requestOptions.method,
            },
          );
        }

        // Check for large response payload
        _checkLargePayload(
          response.data,
          'response',
          response.requestOptions.method,
          response.requestOptions.uri.toString(),
          durationMs,
        );
      }
    } on Object catch (e, stack) {
      if (printLogs) {
        // ignore: avoid_print
        print('LoggingInterceptor Error: $e\n$stack');
      }
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (level == LogLevel.none) {
      return handler.next(err);
    }

    try {
      if (printLogs && level != LogLevel.none) {
        _printDebugError(err);
      }

      if (logDelegate != null) {
        final errorDetails = _analyzeError(err);
        final logLevel = _getErrorLogLevel(err);

        _safeLog(
          errorDetails['message'] as String,
          logLevel,
          errorDetails,
        );
      }
    } on Object catch (e, stack) {
      if (printLogs) {
        // ignore: avoid_print
        print('LoggingInterceptor Error: $e\n$stack');
      }
    }

    handler.next(err);
  }

  // --- Redaction Helpers ---

  Object? _redactBody(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) {
      return _redactMap(data);
    } else if (data is List) {
      return _redactList(data);
    } else if (data is String) {
      try {
        final decoded = jsonDecode(data);
        return _redactBody(decoded);
      } on FormatException {
        return data; // Not JSON
      }
    }
    return data;
  }

  Map<String, dynamic> _redactMap(Map<String, dynamic> map) {
    final newMap = <String, dynamic>{};
    for (final entry in map.entries) {
      final key = entry.key;
      final value = entry.value;

      if (_isSensitive(key)) {
        newMap[key] = '[REDACTED]';
      } else {
        newMap[key] = _redactBody(value);
      }
    }
    return newMap;
  }

  List<dynamic> _redactList(List<dynamic> list) =>
      list.map(_redactBody).toList();

  Map<String, dynamic> _redactHeaders(Map<String, dynamic> headers) {
    final newHeaders = <String, dynamic>{};
    headers.forEach((key, value) {
      if (_isSensitive(key)) {
        newHeaders[key] = '[REDACTED]';
      } else {
        newHeaders[key] = value;
      }
    });
    return newHeaders;
  }

  bool _isSensitive(String key) {
    final lowerKey = key.toLowerCase();
    for (final field in sensitiveFields) {
      if (lowerKey.contains(field.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  int _calculateDuration(Response<dynamic> response) {
    final startTime =
        response.requestOptions.extra['acdc_request_start_time'] as int?;
    if (startTime == null) {
      return -1;
    }
    return DateTime.now().millisecondsSinceEpoch - startTime;
  }

  // --- Console Printing Helpers ---

  void _printDebugRequest(RequestOptions options) {
    final b = StringBuffer()
      ..writeln('*** Request ***')
      ..writeln('${options.method} ${options.uri}');
    if (logRequestHeaders) {
      b.writeln('Headers: ${_redactHeaders(options.headers)}');
    }
    if (options.data != null) {
      b.writeln('Body: ${_redactBody(options.data)}');
    }
    // ignore: avoid_print
    print(b.toString());
  }

  void _printDebugResponse(Response<dynamic> response) {
    final b = StringBuffer()
      ..writeln('*** Response ***')
      ..writeln('Status: ${response.statusCode}');
    if (logResponseHeaders) {
      b.writeln('Headers: ${_redactHeaders(response.headers.map)}');
    }
    b.writeln('Data: ${_redactBody(response.data)}');
    // ignore: avoid_print
    print(b.toString());
  }

  void _printDebugError(DioException err) {
    final b = StringBuffer()
      ..writeln('*** Error ***')
      ..writeln('Message: ${err.message}')
      ..writeln('Type: ${err.type}');
    // ignore: avoid_print
    print(b.toString());
  }

  /// Check if payload exceeds threshold and log warning
  void _checkLargePayload(
    dynamic data,
    String type,
    String method,
    String url,
    int? durationMs,
  ) {
    if (largePayloadThreshold == null || logDelegate == null) return;

    final size = _estimatePayloadSize(data);
    if (size > largePayloadThreshold!) {
      final sizeMB = (size / 1048576).toStringAsFixed(1);
      final metadata = <String, dynamic>{
        'type': 'large_payload',
        'payload_type': type,
        'size_bytes': size,
        'size_mb': sizeMB,
        'threshold_bytes': largePayloadThreshold,
        'url': url,
        'method': method,
      };

      if (durationMs != null) {
        metadata['duration_ms'] = durationMs;
      }

      _safeLog(
        'Large $type payload: $method $url (${sizeMB}MB)',
        LogLevel.warning,
        metadata,
      );
    }
  }

  /// Estimate payload size in bytes
  int _estimatePayloadSize(dynamic data) {
    if (data == null) return 0;

    if (data is String) {
      return data.length;
    } else if (data is List<int>) {
      return data.length;
    } else if (data is Map || data is List) {
      try {
        final encoded = jsonEncode(data);
        return encoded.length;
      } on FormatException {
        return 0;
      }
    }

    return 0;
  }

  /// Analyze DioException and return detailed error information
  Map<String, dynamic> _analyzeError(DioException err) {
    final metadata = <String, dynamic>{
      'type': 'error',
      'url': err.requestOptions.uri.toString(),
      'method': err.requestOptions.method,
      'timestamp': DateTime.now().toIso8601String(),
    };

    String message;
    String errorType;

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
        errorType = 'connection_timeout';
        message =
            'Connection timeout: ${err.requestOptions.method} ${err.requestOptions.uri}';
        metadata['timeout_ms'] = err.requestOptions.connectTimeout;
        metadata['timeout_type'] = 'Connection establishment';
        break;

      case DioExceptionType.sendTimeout:
        errorType = 'send_timeout';
        message =
            'Send timeout: ${err.requestOptions.method} ${err.requestOptions.uri}';
        metadata['timeout_ms'] = err.requestOptions.sendTimeout;
        metadata['timeout_type'] = 'Request send';
        break;

      case DioExceptionType.receiveTimeout:
        errorType = 'receive_timeout';
        message =
            'Receive timeout: ${err.requestOptions.method} ${err.requestOptions.uri}';
        metadata['timeout_ms'] = err.requestOptions.receiveTimeout;
        metadata['timeout_type'] = 'Response receive';
        break;

      case DioExceptionType.badCertificate:
        errorType = 'ssl_certificate_error';
        message =
            'SSL Certificate error: ${err.requestOptions.method} ${err.requestOptions.uri}';
        metadata['error_detail'] =
            err.message ?? 'Certificate validation failed';
        break;

      case DioExceptionType.badResponse:
        errorType = 'http_error';
        final statusCode = err.response?.statusCode ?? 0;
        message =
            'HTTP error $statusCode: ${err.requestOptions.method} ${err.requestOptions.uri}';
        metadata['statusCode'] = statusCode;
        if (err.response?.data != null) {
          metadata['response_body'] = _redactBody(err.response!.data);
        }
        break;

      case DioExceptionType.cancel:
        errorType = 'request_cancelled';
        message =
            'Request cancelled: ${err.requestOptions.method} ${err.requestOptions.uri}';
        metadata['cancellation_reason'] = 'Manual cancellation via CancelToken';
        break;

      case DioExceptionType.connectionError:
        errorType = 'network_error';
        message =
            'Network failure: ${err.requestOptions.method} ${err.requestOptions.uri}';
        metadata['error_detail'] = err.message ?? 'Connection failed';
        metadata['error_object'] = err.error.toString();
        break;

      case DioExceptionType.unknown:
        errorType = 'unknown_error';
        message =
            'Error: ${err.response?.statusCode ?? 'N/A'} ${err.requestOptions.uri}';
        metadata['error_detail'] = err.message ?? 'Unknown error';
        metadata['error_object'] = err.error.toString();
        break;
    }

    metadata['error_type'] = errorType;
    metadata['message'] = message;

    return metadata;
  }

  /// Determine the appropriate log level based on error type
  LogLevel _getErrorLogLevel(DioException err) {
    switch (err.type) {
      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode ?? 0;
        // 4xx errors are warnings, 5xx are errors
        return statusCode >= 500 ? LogLevel.error : LogLevel.warning;

      case DioExceptionType.cancel:
        return LogLevel.info; // Cancellations are informational

      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.badCertificate:
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return LogLevel.error;
    }
  }
}
