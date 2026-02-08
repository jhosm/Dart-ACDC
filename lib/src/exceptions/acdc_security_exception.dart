import 'package:dart_acdc/src/exceptions/acdc_exception.dart';
import 'package:dio/dio.dart';

/// Exception thrown when a security check fails, such as Certificate Pinning.
class AcdcSecurityException extends AcdcException {
  /// Creates an AcdcSecurityException.
  AcdcSecurityException({
    required super.requestOptions,
    required this.hostname,
    super.message = 'Security check failed',
    this.peerCertificates,
    super.originalException,
    super.requestUrl,
    super.stackTrace,
    super.type,
    super.error,
  });

  /// Factory constructor from DioException.
  factory AcdcSecurityException.fromDioException(
    DioException exception,
  ) {
    final hostname = exception.requestOptions.uri.host;
    final message = exception.type == DioExceptionType.badCertificate
        ? 'Certificate validation failed for $hostname'
        : 'Security check failed';

    return AcdcSecurityException(
      requestOptions: exception.requestOptions,
      hostname: hostname,
      message: message,
      originalException: exception,
      requestUrl:
          AcdcException.redactUrl(exception.requestOptions.uri.toString()),
      stackTrace: exception.stackTrace,
      type: exception.type,
      error: exception.error,
    );
  }

  /// The hostname that failed validation.
  final String hostname;

  /// The list of peer certificates (SHA-256 SPKI hashes) encountered during the connection.
  ///
  /// This helps developers identify which keys the server is actually presenting,
  /// useful for debugging pinning configuration mismatch.
  final List<String>? peerCertificates;

  @override
  String toString() {
    final buffer = StringBuffer()
      ..write('AcdcSecurityException: $message\n')
      ..write('  Hostname: $hostname\n');
    if (peerCertificates != null && peerCertificates!.isNotEmpty) {
      buffer.write('  Peer Certificates (Server presented):\n');
      for (final cert in peerCertificates!) {
        buffer.write('    - $cert\n');
      }
    }
    if (requestUrl != null) {
      buffer.write('  URL: $requestUrl\n');
    }
    return buffer.toString();
  }
}
