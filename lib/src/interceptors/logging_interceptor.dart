import 'dart:convert';
import 'package:dart_acdc/src/logging/acdc_logger.dart';
import 'package:dart_acdc/src/logging/log_level.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

/// Interceptor that handles logging of requests, responses, and errors.
///
/// Features:
/// - Human-readable console logs in debug mode (via [PrettyDioLogger]).
/// - Structured logging via optional [AcdcLogger] callback.
/// - Adjustable verbosity levels.
/// - Automatic redaction of sensitive fields (headers and body).
/// - Resilient error handling (logging failures don't break the app).
class LoggingInterceptor extends Interceptor {
  /// Creates a new [LoggingInterceptor].
  LoggingInterceptor({
    this.level = LogLevel.info,
    this.logger,
    List<String>? sensitiveFields,
    this.logRequestHeaders = true,
    this.logResponseHeaders = true,
    this.maxWidth = 120,
    this.compact = true,
  }) : sensitiveFields = sensitiveFields ??
            const [
              'password',
              'token',
              'secret',
              'access_token',
              'refresh_token',
              'client_secret',
              'authorization',
            ];

  /// The log verbosity level.
  final LogLevel level;

  /// Custom logger function.
  final AcdcLogger? logger;

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

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (level == LogLevel.none) {
      return handler.next(options);
    }

    try {
      // 1. Pretty Print (Debug Only)
      if (kDebugMode && level != LogLevel.none) {
        // We manually print a debug representation that respects our redaction rules.
        _printDebugRequest(options);
      }

      // 2. Structured / Custom Logging
      if (logger != null) {
        // Track request start time for duration calculation in response
        options.extra['acdc_request_start_time'] =
            DateTime.now().millisecondsSinceEpoch;

        final redactedBody = _redactBody(options.data);
        final redactedHeaders = _redactHeaders(options.headers);

        logger!(
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
      }
    } catch (e, stack) {
      // Resilience: never crash request due to logging
      debugPrint('LoggingInterceptor Error: $e\n$stack');
    }

    // We must call next since we didn't delegate to another interceptor
    handler.next(options);
  }

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) {
    if (level == LogLevel.none) {
      return handler.next(response);
    }

    try {
      if (kDebugMode && level != LogLevel.none) {
        _printDebugResponse(response);
      }

      if (logger != null) {
        final redactedBody = _redactBody(response.data);
        final redactedHeaders = _redactHeaders(response.headers.map);

        logger!(
          'Response: ${response.statusCode} ${response.requestOptions.uri}',
          level,
          {
            'type': 'response',
            'statusCode': response.statusCode,
            'url': response.requestOptions.uri.toString(),
            'headers': redactedHeaders,
            'body': redactedBody,
            'duration_ms': _calculateDuration(response),
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }
    } catch (e, stack) {
      debugPrint('LoggingInterceptor Error: $e\n$stack');
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (level == LogLevel.none) {
      return handler.next(err);
    }

    try {
      if (kDebugMode && level != LogLevel.none) {
        _printDebugError(err);
      }

      if (logger != null) {
        logger!(
          'Error: ${err.response?.statusCode ?? 'N/A'} ${err.requestOptions.uri}',
          LogLevel.error,
          {
            'type': 'error',
            'statusCode': err.response?.statusCode,
            'url': err.requestOptions.uri.toString(),
            'message': err.message,
            'error': err.error.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }
    } catch (e, stack) {
      debugPrint('LoggingInterceptor Error: $e\n$stack');
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
      } catch (_) {
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

  List<dynamic> _redactList(List<dynamic> list) {
    return list.map((e) => _redactBody(e)).toList();
  }

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

  // --- Quick Debug Printing Helpers (Replacements for PrettyDioLogger if we don't use it directly) ---

  void _printDebugRequest(RequestOptions options) {
    final b = StringBuffer();
    b.writeln('*** Request ***');
    b.writeln('${options.method} ${options.uri}');
    if (logRequestHeaders) {
      b.writeln('Headers: ${_redactHeaders(options.headers)}');
    }
    if (options.data != null) {
      b.writeln('Body: ${_redactBody(options.data)}');
    }
    debugPrint(b.toString());
  }

  void _printDebugResponse(Response<dynamic> response) {
    final b = StringBuffer();
    b.writeln('*** Response ***');
    b.writeln('Status: ${response.statusCode}');
    if (logResponseHeaders) {
      b.writeln('Headers: ${_redactHeaders(response.headers.map)}');
    }
    b.writeln('Data: ${_redactBody(response.data)}');
    debugPrint(b.toString());
  }

  void _printDebugError(DioException err) {
    final b = StringBuffer();
    b.writeln('*** Error ***');
    b.writeln('Message: ${err.message}');
    b.writeln('Type: ${err.type}');
    debugPrint(b.toString());
  }
}
