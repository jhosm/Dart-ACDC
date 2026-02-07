import 'package:dart_acdc/src/exceptions/acdc_security_exception.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  group('AcdcSecurityException', () {
    test('creates exception with required parameters', () {
      final exception = AcdcSecurityException(
        requestOptions: RequestOptions(path: '/test'),
        hostname: 'example.com',
      );

      expect(exception.hostname, equals('example.com'));
      expect(exception.message, equals('Security check failed'));
      expect(exception.peerCertificates, isNull);
    });

    test('creates exception with custom message', () {
      final exception = AcdcSecurityException(
        requestOptions: RequestOptions(path: '/test'),
        hostname: 'example.com',
        message: 'Certificate pinning failed',
      );

      expect(exception.message, equals('Certificate pinning failed'));
    });

    test('creates exception with peer certificates', () {
      final exception = AcdcSecurityException(
        requestOptions: RequestOptions(path: '/test'),
        hostname: 'example.com',
        peerCertificates: [
          'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
          'sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=',
        ],
      );

      expect(exception.peerCertificates, isNotNull);
      expect(exception.peerCertificates!.length, equals(2));
    });

    test('toString includes hostname', () {
      final exception = AcdcSecurityException(
        requestOptions: RequestOptions(path: '/test'),
        hostname: 'example.com',
      );

      final str = exception.toString();
      expect(str, contains('AcdcSecurityException'));
      expect(str, contains('example.com'));
    });

    test('toString includes peer certificates when present', () {
      final exception = AcdcSecurityException(
        requestOptions: RequestOptions(path: '/test'),
        hostname: 'example.com',
        peerCertificates: [
          'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
        ],
      );

      final str = exception.toString();
      expect(str, contains('Peer Certificates'));
      expect(str, contains('sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='));
    });

    test('toString includes URL when available', () {
      final exception = AcdcSecurityException(
        requestOptions: RequestOptions(
          path: '/test',
          baseUrl: 'https://example.com',
        ),
        hostname: 'example.com',
      );

      final str = exception.toString();
      expect(str, contains('URL:'));
    });

    test('extends AcdcException', () {
      final exception = AcdcSecurityException(
        requestOptions: RequestOptions(path: '/test'),
        hostname: 'example.com',
      );

      expect(exception, isA<AcdcSecurityException>());
    });
  });
}
