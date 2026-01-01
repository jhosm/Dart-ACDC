import 'package:dart_acdc/src/exceptions/acdc_exception.dart';
import 'package:dio/dio.dart';

/// Exception for authentication and authorization errors.
///
/// Thrown for HTTP 401 (Unauthorized) and 403 (Forbidden) responses.
class AcdcAuthException extends AcdcException {
  /// Creates an authentication exception.
  AcdcAuthException({
    required super.requestOptions,
    required super.message,
    super.originalException,
    super.statusCode,
    super.response,
    super.responseData,
    super.requestUrl,
    super.error,
    super.stackTrace,
  }) : super(
          type: DioExceptionType.badResponse,
        );

  /// Factory constructor from DioException with 401/403 response.
  ///
  /// Optionally accepts a custom [message] to override the default message.
  factory AcdcAuthException.fromDioException(
    DioException exception, {
    String? message,
  }) {
    final response = exception.response;
    final statusCode = response?.statusCode ?? 0;
    final url = AcdcException.redactUrl(
      exception.requestOptions.uri.toString(),
    );
    final responseBody = AcdcException.truncateResponseBody(
      response?.data,
    );

    // Use custom message if provided, otherwise generate default
    final errorMessage = message ?? _defaultMessage(statusCode);

    return AcdcAuthException(
      requestOptions: exception.requestOptions,
      message: errorMessage,
      originalException: exception,
      statusCode: statusCode,
      response: response,
      responseData: responseBody,
      requestUrl: url,
      error: exception.error,
      stackTrace: exception.stackTrace,
    );
  }

  /// Generates default error message based on status code.
  static String _defaultMessage(int statusCode) {
    if (statusCode == 401) {
      return 'Authentication failed: Invalid or expired token';
    } else if (statusCode == 403) {
      return 'Authorization failed: Insufficient permissions';
    } else {
      return 'Authentication error (HTTP $statusCode)';
    }
  }
}
