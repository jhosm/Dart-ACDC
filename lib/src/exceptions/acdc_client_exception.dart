import 'package:dart_acdc/src/exceptions/acdc_exception.dart';
import 'package:dio/dio.dart';

/// Exception for client-side errors.
///
/// Thrown for HTTP 4xx responses (except 401/403) indicating client mistakes:
/// - 400 Bad Request
/// - 404 Not Found
/// - 422 Unprocessable Entity
/// - 429 Too Many Requests
/// - etc.
class AcdcClientException extends AcdcException {
  /// Creates a client exception.
  AcdcClientException({
    required super.requestOptions,
    required super.message,
    required super.originalException,
    required super.statusCode,
    super.response,
    super.responseData,
    super.requestUrl,
    this.retryAfter,
    super.error,
    super.stackTrace,
  }) : super(
          type: DioExceptionType.badResponse,
        );

  /// Factory constructor from DioException with 4xx response.
  factory AcdcClientException.fromDioException(
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

    // Parse Retry-After header for 429 responses
    Duration? retryAfter;
    if (statusCode == 429) {
      retryAfter = _parseRetryAfter(response?.headers);
    }

    final message = _generateMessage(statusCode, retryAfter);

    return AcdcClientException(
      requestOptions: exception.requestOptions,
      message: message,
      originalException: exception,
      statusCode: statusCode,
      response: response,
      responseData: responseBody,
      requestUrl: url,
      retryAfter: retryAfter,
      error: exception.error,
      stackTrace: exception.stackTrace,
    );
  }

  /// Retry-After duration for 429 Too Many Requests.
  ///
  /// Null if not applicable or header not present.
  final Duration? retryAfter;

  static String _generateMessage(int statusCode, Duration? retryAfter) {
    switch (statusCode) {
      case 400:
        return 'Bad Request (HTTP 400): Invalid request parameters';
      case 404:
        return 'Not Found (HTTP 404): Requested resource does not exist';
      case 422:
        return 'Unprocessable Entity (HTTP 422): Validation failed';
      case 429:
        final retryMsg = retryAfter != null
            ? ' Retry after ${retryAfter.inSeconds} seconds.'
            : '';
        return 'Too Many Requests (HTTP 429): Rate limit exceeded.$retryMsg';
      default:
        return 'Client error (HTTP $statusCode): Request could not be processed';
    }
  }

  static Duration? _parseRetryAfter(Headers? headers) {
    if (headers == null) return null;

    final retryAfterValues = headers['retry-after'];
    if (retryAfterValues == null || retryAfterValues.isEmpty) return null;

    final retryAfterStr = retryAfterValues.first;

    // Try parsing as seconds (integer)
    final seconds = int.tryParse(retryAfterStr);
    if (seconds != null) {
      return Duration(seconds: seconds);
    }

    // Try parsing as HTTP date
    final httpDate = DateTime.tryParse(retryAfterStr);
    if (httpDate != null) {
      final diff = httpDate.difference(DateTime.now());
      return diff.isNegative ? Duration.zero : diff;
    }

    return null;
  }

  @override
  Map<String, dynamic> toMap() => {
        ...super.toMap(),
        'retryAfter': retryAfter?.inSeconds,
      };
}
