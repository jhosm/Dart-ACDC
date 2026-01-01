import 'package:dio/dio.dart';

/// Base exception class for all Dart-ACDC exceptions.
///
/// Extends [DioException] for backward compatibility while providing
/// developer-friendly error categorization and messages.
class AcdcException extends DioException {
  /// Creates an ACDC exception.
  ///
  /// [message] is a developer-focused error message with technical context.
  /// [originalException] preserves the original [DioException] for debugging (optional).
  /// [statusCode] is the HTTP status code if available.
  /// [responseData] is the truncated response body (max 1KB).
  /// [requestUrl] is the redacted request URL.
  AcdcException({
    required super.requestOptions,
    required this.message,
    this.originalException,
    this.statusCode,
    this.responseData,
    this.requestUrl,
    super.response,
    super.type = DioExceptionType.unknown,
    super.error,
    super.stackTrace,
  }) : super(message: message);

  /// Developer-focused error message with technical context.
  @override
  final String message;

  /// The original [DioException] for low-level debugging.
  ///
  /// May be null if the exception was created internally without an underlying DioException.
  final DioException? originalException;

  /// HTTP status code if available.
  final int? statusCode;

  /// Response body truncated to 1KB for safety.
  final dynamic responseData;

  /// Redacted request URL (sensitive parameters removed).
  final String? requestUrl;

  /// Converts exception to a structured map for logging.
  ///
  /// Includes all relevant debugging information in a machine-readable format.
  Map<String, dynamic> toMap() => {
        'type': runtimeType.toString(),
        'message': message,
        'statusCode': statusCode,
        'requestUrl': requestUrl,
        'responseData': responseData,
        'originalError': originalException.toString(),
      };

  @override
  String toString() => '$runtimeType: $message'
      '${statusCode != null ? ' (HTTP $statusCode)' : ''}'
      '${requestUrl != null ? '\nURL: $requestUrl' : ''}';

  /// Truncates response body to 1KB limit.
  static String? truncateResponseBody(dynamic body, {int maxLength = 1024}) {
    if (body == null) return null;
    final bodyStr = body.toString();
    if (bodyStr.length <= maxLength) return bodyStr;
    return '${bodyStr.substring(0, maxLength)}... (truncated)';
  }

  /// Redacts sensitive URL parameters.
  ///
  /// Removes or masks query parameters like:
  /// - token, access_token, refresh_token
  /// - api_key, apikey, key
  /// - password, pwd, secret
  static String redactUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;

    if (uri.queryParameters.isEmpty) return url;

    final sensitiveParams = {
      'token',
      'access_token',
      'refresh_token',
      'api_key',
      'apikey',
      'key',
      'password',
      'pwd',
      'secret',
    };

    final redactedParams = Map<String, String>.from(uri.queryParameters);
    for (final param in uri.queryParameters.keys) {
      if (sensitiveParams.any(
        (s) => param.toLowerCase().contains(s),
      )) {
        redactedParams[param] = '***REDACTED***';
      }
    }

    return uri.replace(queryParameters: redactedParams).toString();
  }
}
