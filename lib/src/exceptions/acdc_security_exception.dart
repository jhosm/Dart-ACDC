import 'package:dart_acdc/src/exceptions/acdc_exception.dart';

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
  });

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
