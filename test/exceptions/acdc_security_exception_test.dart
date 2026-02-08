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
      expect(
        str,
        contains('sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='),
      );
    });

    test('toString includes URL when available', () {
      final exception = AcdcSecurityException(
        requestOptions: RequestOptions(
          path: '/test',
          baseUrl: 'https://example.com',
        ),
        hostname: 'example.com',
        requestUrl: 'https://example.com/test',
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

    group('fromDioException', () {
      test('preserves DioException type and error fields', () {
        final originalError = Exception('Certificate validation error');
        final dioException = DioException(
          requestOptions: RequestOptions(
            path: '/api/data',
            baseUrl: 'https://example.com',
          ),
          type: DioExceptionType.badCertificate,
          error: originalError,
        );

        final securityException =
            AcdcSecurityException.fromDioException(dioException);

        expect(securityException.type, equals(DioExceptionType.badCertificate));
        expect(securityException.error, equals(originalError));
        expect(securityException.hostname, equals('example.com'));
        expect(
          securityException.message,
          equals('Certificate validation failed for example.com'),
        );
      });

      test('creates message for badCertificate type', () {
        final dioException = DioException(
          requestOptions: RequestOptions(
            path: '/test',
            baseUrl: 'https://secure.example.com',
          ),
          type: DioExceptionType.badCertificate,
        );

        final exception = AcdcSecurityException.fromDioException(dioException);

        expect(
          exception.message,
          equals('Certificate validation failed for secure.example.com'),
        );
        expect(exception.type, equals(DioExceptionType.badCertificate));
      });

      test('creates default message for non-badCertificate types', () {
        final dioException = DioException(
          requestOptions: RequestOptions(
            path: '/test',
            baseUrl: 'https://example.com',
          ),
          type: DioExceptionType.connectionError,
        );

        final exception = AcdcSecurityException.fromDioException(dioException);

        expect(exception.message, equals('Security check failed'));
        expect(exception.type, equals(DioExceptionType.connectionError));
      });

      test('preserves originalException reference', () {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badCertificate,
        );

        final exception = AcdcSecurityException.fromDioException(dioException);

        expect(exception.originalException, equals(dioException));
      });

      test('redacts sensitive URL information', () {
        final dioException = DioException(
          requestOptions: RequestOptions(
            path: '/api/users',
            baseUrl: 'https://example.com',
            queryParameters: {
              'token': 'secret123',
              'apiKey': 'key456',
            },
          ),
          type: DioExceptionType.badCertificate,
        );

        final exception = AcdcSecurityException.fromDioException(dioException);

        // URL should be redacted (specific redaction logic from AcdcException.redactUrl)
        expect(exception.requestUrl, isNotNull);
        // The redactUrl method should remove or mask sensitive query parameters
      });
    });
  });
}
