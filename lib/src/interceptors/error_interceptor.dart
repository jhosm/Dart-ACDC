import 'dart:io';

import 'package:dart_acdc/src/exceptions/acdc_auth_exception.dart';
import 'package:dart_acdc/src/exceptions/acdc_client_exception.dart';
import 'package:dart_acdc/src/exceptions/acdc_exception.dart';
import 'package:dart_acdc/src/exceptions/acdc_network_exception.dart';
import 'package:dart_acdc/src/exceptions/acdc_security_exception.dart';
import 'package:dart_acdc/src/exceptions/acdc_server_exception.dart';
import 'package:dio/dio.dart';

/// Interceptor that converts DioExceptions into type-safe ACDC exceptions.
///
/// Maps HTTP status codes and network errors to developer-friendly exceptions:
/// - Certificate errors → [AcdcSecurityException]
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
    // Handle certificate errors
    if (exception.type == DioExceptionType.badCertificate) {
      return AcdcSecurityException.fromDioException(exception);
    }

    // Handle network-related errors
    if (_isNetworkError(exception)) {
      return AcdcNetworkException.fromDioException(exception);
    }

    // Handle malformed response (parse errors)
    if (_isMalformedResponse(exception)) {
      return _createMalformedResponseException(exception);
    }

    // Handle HTTP response errors
    final statusCode = exception.response?.statusCode;
    if (statusCode != null) {
      // Redirect handling (3xx) when automatic redirects are disabled
      if (statusCode >= 300 && statusCode < 400) {
        return _createRedirectException(exception);
      }

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
      case DioExceptionType.unknown:
        // Check if it's a connection error despite being marked as unknown
        // Use type checking instead of string matching for reliability
        if (exception.error != null) {
          // SocketException and its subclasses cover most network errors
          if (exception.error is SocketException) {
            return true;
          }
        }
        return false;
    }
  }

  /// Checks if the exception is due to a malformed response.
  bool _isMalformedResponse(DioException exception) {
    if (exception.type == DioExceptionType.unknown && exception.error != null) {
      final error = exception.error;
      // Check for common parsing errors
      return error is FormatException ||
          error.toString().toLowerCase().contains('format') ||
          error.toString().toLowerCase().contains('parse') ||
          error.toString().toLowerCase().contains('invalid json');
    }
    return false;
  }

  /// Creates an AcdcClientException for malformed responses.
  AcdcClientException _createMalformedResponseException(
    DioException exception,
  ) {
    final url = AcdcException.redactUrl(
      exception.requestOptions.uri.toString(),
    );
    final responseBody = AcdcException.truncateResponseBody(
      exception.response?.data,
    );

    return AcdcClientException(
      requestOptions: exception.requestOptions,
      message: 'Invalid response format from server',
      originalException: exception,
      statusCode: exception.response?.statusCode,
      response: exception.response,
      responseData: responseBody,
      requestUrl: url,
      error: exception.error,
      stackTrace: exception.stackTrace,
    );
  }

  /// Creates an AcdcClientException for redirect responses.
  AcdcClientException _createRedirectException(DioException exception) {
    final location = exception.response?.headers.value('location') ?? 'unknown';
    final url = AcdcException.redactUrl(
      exception.requestOptions.uri.toString(),
    );

    return AcdcClientException(
      requestOptions: exception.requestOptions,
      message: 'Unexpected redirect to $location',
      originalException: exception,
      statusCode: exception.response?.statusCode,
      response: exception.response,
      requestUrl: url,
      error: exception.error,
      stackTrace: exception.stackTrace,
    );
  }
}
