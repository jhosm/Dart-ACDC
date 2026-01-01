import 'package:dart_acdc/src/exceptions/acdc_exception.dart';
import 'package:dio/dio.dart';

/// Exception for server-side errors.
///
/// Thrown for HTTP 5xx responses indicating server failures.
class AcdcServerException extends AcdcException {
  /// Creates a server exception.
  AcdcServerException({
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

  /// Factory constructor from DioException with 5xx response.
  factory AcdcServerException.fromDioException(
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

    final message = 'Server error (HTTP $statusCode): '
        'The server encountered an error processing your request';

    return AcdcServerException(
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
