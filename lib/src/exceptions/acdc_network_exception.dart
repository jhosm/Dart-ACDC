import 'package:dart_acdc/src/exceptions/acdc_exception.dart';
import 'package:dio/dio.dart';

/// Network error types for categorization.
enum NetworkErrorType {
  /// Connection timeout (CONNECT_TIMEOUT).
  connectionTimeout,

  /// Send timeout (SEND_TIMEOUT).
  sendTimeout,

  /// Receive timeout (RECEIVE_TIMEOUT).
  receiveTimeout,

  /// No internet connection or unreachable host.
  noConnection,

  /// Connection cancelled by user or app.
  cancelled,

  /// Other network-related errors.
  other,
}

/// Exception for network-related errors.
///
/// Thrown when network connectivity issues prevent request completion:
/// - Connection timeouts
/// - Send/receive timeouts
/// - No internet connection
/// - Connection cancelled
class AcdcNetworkException extends AcdcException {
  /// Creates a network exception.
  AcdcNetworkException({
    required super.requestOptions,
    required super.message,
    required DioException super.originalException,
    required this.networkErrorType,
    super.error,
    super.stackTrace,
  }) : super(
          type: originalException.type,
        );

  /// Factory constructor from DioException.
  factory AcdcNetworkException.fromDioException(
    DioException exception,
  ) {
    final errorType = _mapDioTypeToNetworkType(exception.type);
    final message = _generateMessage(errorType, exception);

    return AcdcNetworkException(
      requestOptions: exception.requestOptions,
      message: message,
      originalException: exception,
      networkErrorType: errorType,
      error: exception.error,
      stackTrace: exception.stackTrace,
    );
  }

  /// The specific network error type.
  final NetworkErrorType networkErrorType;

  static NetworkErrorType _mapDioTypeToNetworkType(DioExceptionType type) {
    switch (type) {
      case DioExceptionType.connectionTimeout:
        return NetworkErrorType.connectionTimeout;
      case DioExceptionType.sendTimeout:
        return NetworkErrorType.sendTimeout;
      case DioExceptionType.receiveTimeout:
        return NetworkErrorType.receiveTimeout;
      case DioExceptionType.cancel:
        return NetworkErrorType.cancelled;
      case DioExceptionType.connectionError:
        return NetworkErrorType.noConnection;
      default:
        return NetworkErrorType.other;
    }
  }

  static String _generateMessage(
    NetworkErrorType errorType,
    DioException exception,
  ) {
    final url = AcdcException.redactUrl(
      exception.requestOptions.uri.toString(),
    );

    switch (errorType) {
      case NetworkErrorType.connectionTimeout:
        return 'Connection timeout while connecting to $url';
      case NetworkErrorType.sendTimeout:
        return 'Send timeout while sending data to $url';
      case NetworkErrorType.receiveTimeout:
        return 'Receive timeout while waiting for response from $url';
      case NetworkErrorType.noConnection:
        return 'No internet connection or unable to reach $url';
      case NetworkErrorType.cancelled:
        return 'Request to $url was cancelled';
      case NetworkErrorType.other:
        return 'Network error occurred: ${exception.message ?? "Unknown error"}';
    }
  }

  @override
  Map<String, dynamic> toMap() => {
        ...super.toMap(),
        'networkErrorType': networkErrorType.name,
      };
}
