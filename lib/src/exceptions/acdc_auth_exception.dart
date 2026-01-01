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
    required super.originalException,
    required super.statusCode,
    super.response,
    super.responseData,
    super.requestUrl,
    super.error,
    super.stackTrace,
  }) : super(
          type: DioExceptionType.badResponse,
        );

  /// Factory constructor from DioException with 401/403 response.
  factory AcdcAuthException.fromDioException(
    DioException exception,
  ) {
    final response = exception.response;
    final statusCode = response?.statusCode ?? 0;
    final url = AcdcException.redactUrl(
      exception.requestOptions.uri.toString(),
    );
    final responseBody = AcdcException.truncateResponseBody(
      response?.data,
    );

    String message;
    if (statusCode == 401) {
      message = 'Authentication failed: Invalid or expired token';
    } else if (statusCode == 403) {
      message = 'Authorization failed: Insufficient permissions';
    } else {
      message = 'Authentication error (HTTP $statusCode)';
    }

    return AcdcAuthException(
      requestOptions: exception.requestOptions,
      message: message,
      originalException: exception,
      statusCode: statusCode,
      response: response,
      responseData: responseBody,
      requestUrl: url,
      error: exception.error,
      stackTrace: exception.stackTrace,
    );
  }
}
