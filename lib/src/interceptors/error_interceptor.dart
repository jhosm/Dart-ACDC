import 'package:dart_acdc/src/exceptions/acdc_auth_exception.dart';
import 'package:dart_acdc/src/exceptions/acdc_client_exception.dart';
import 'package:dart_acdc/src/exceptions/acdc_network_exception.dart';
import 'package:dart_acdc/src/exceptions/acdc_server_exception.dart';
import 'package:dio/dio.dart';

/// Interceptor that converts DioExceptions into type-safe ACDC exceptions.
///
/// Maps HTTP status codes and network errors to developer-friendly exceptions:
/// - 401/403 → [AcdcAuthException]
/// - 4xx (others) → [AcdcClientException]
/// - 5xx → [AcdcServerException]
/// - Network errors → [AcdcNetworkException]
///
/// **Important**: This interceptor must run AFTER the auth interceptor
/// in the response chain so that 401 responses handled by auth refresh
/// don't get converted to exceptions.
class ErrorInterceptor extends Interceptor {
  /// Creates an error interceptor.
  const ErrorInterceptor();

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Convert DioException to appropriate ACDC exception
    final acdcException = _convertException(err);

    // Pass converted exception to next handler
    handler.next(acdcException);
  }

  /// Converts a DioException to the appropriate ACDC exception type.
  DioException _convertException(DioException exception) {
    // Handle network-related errors first
    if (_isNetworkError(exception)) {
      return AcdcNetworkException.fromDioException(exception);
    }

    // Handle HTTP response errors
    final statusCode = exception.response?.statusCode;
    if (statusCode != null) {
      // Authentication errors (401, 403)
      if (statusCode == 401 || statusCode == 403) {
        return AcdcAuthException.fromDioException(exception);
      }

      // Server errors (5xx)
      if (statusCode >= 500 && statusCode < 600) {
        return AcdcServerException.fromDioException(exception);
      }

      // Client errors (4xx, except 401/403)
      if (statusCode >= 400 && statusCode < 500) {
        return AcdcClientException.fromDioException(exception);
      }
    }

    // For all other cases, return original exception
    // (shouldn't normally happen, but defensive programming)
    return exception;
  }

  /// Checks if the exception is network-related.
  bool _isNetworkError(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.cancel:
        return true;
      case DioExceptionType.badResponse:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        // Check if it's a connection error despite being marked as unknown
        if (exception.error != null) {
          final errorStr = exception.error.toString().toLowerCase();
          // Common network error patterns
          if (errorStr.contains('socketexception') ||
              errorStr.contains('failed host lookup') ||
              errorStr.contains('network is unreachable') ||
              errorStr.contains('software caused connection abort') ||
              errorStr.contains('connection refused') ||
              errorStr.contains('connection reset')) {
            return true;
          }
        }
        return false;
    }
  }
}
