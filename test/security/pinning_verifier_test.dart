import 'dart:io';

import 'package:dart_acdc/src/exceptions/acdc_security_exception.dart';
import 'package:dart_acdc/src/security/certificate_pinning_config.dart';
import 'package:dart_acdc/src/security/pinning_verifier.dart';
import 'package:mockito/annotations.dart';
import 'package:test/test.dart';

import 'pinning_verifier_test.mocks.dart';

@GenerateMocks([X509Certificate])
void main() {
  group('PinningVerifier', () {
    late MockX509Certificate mockCert1;
    late MockX509Certificate mockCert2;

    // Test extractor that maps cert instances to pre-defined strings
    String tempExtractor(X509Certificate cert) {
      if (cert == mockCert1) return 'SHA256:CERT1';
      if (cert == mockCert2) return 'SHA256:CERT2';
      return 'SHA256:UNKNOWN';
    }

    setUp(() {
      mockCert1 = MockX509Certificate();
      mockCert2 = MockX509Certificate();
    });

    test('allows unpinned domain', () {
      final config = CertificatePinningConfig(allowedPins: const {});
      PinningVerifier(config, spkiExtractor: tempExtractor)
          // Should not throw
          .verify('google.com', [mockCert1]);
    });

    test('verifies exact match success', () {
      final config = CertificatePinningConfig(
        allowedPins: const {
          'example.com': ['SHA256:CERT1'],
        },
      );

      PinningVerifier(config, spkiExtractor: tempExtractor).verify(
        'example.com',
        [mockCert2, mockCert1],
      ); // Chain contains matched cert
    });

    test('fails when no match found in chain', () {
      final config = CertificatePinningConfig(
        allowedPins: const {
          'example.com': ['SHA256:OTHER'],
        },
      );

      final verifier = PinningVerifier(config, spkiExtractor: tempExtractor);

      expect(
        () => verifier.verify('example.com', [mockCert1, mockCert2]),
        throwsA(
          isA<AcdcSecurityException>().having(
            (e) => e.hostname,
            'hostname',
            'example.com',
          ),
        ),
      );
    });

    test('verifies wildcard match success', () {
      final config = CertificatePinningConfig(
        allowedPins: const {
          '*.example.com': ['SHA256:CERT1'],
        },
      );

      PinningVerifier(config, spkiExtractor: tempExtractor)
          // api.example.com matches *.example.com
          .verify('api.example.com', [mockCert1]);
    });

    test('wildcard does not match root or deep subdomains', () {
      final config = CertificatePinningConfig(
        allowedPins: const {
          '*.example.com': ['SHA256:CERT1'],
        },
      );

      PinningVerifier(config, spkiExtractor: tempExtractor)
        // example.com should NOT match *.example.com -> passes as unpinned
        ..verify('example.com', [mockCert1])
        // deep.api.example.com should NOT match *.example.com -> passes as unpinned
        ..verify('deep.api.example.com', [mockCert1]);
    });

    test('reportOnly mode does not throw but calls callback on failure', () {
      var callbackCalled = false;
      final config = CertificatePinningConfig(
        allowedPins: const {
          'example.com': ['SHA256:MISSING'],
        },
        reportOnly: true,
        onPinningFailure: (host, certs) {
          callbackCalled = true;
          expect(host, 'example.com');
          expect(certs, contains('SHA256:CERT1'));
        },
      );
      PinningVerifier(
        config,
        spkiExtractor: tempExtractor,
      ).verify('example.com', [mockCert1]);
      expect(callbackCalled, isTrue);
    });

    test('debug bypass skips verification', () {
      // Assuming assertions are enabled in test environment
      final config = CertificatePinningConfig(
        allowedPins: const {
          'example.com': ['SHA256:MISSING'],
        },
        enablePinningInDebug: false,
      );

      PinningVerifier(config, spkiExtractor: tempExtractor)
          // Should succeed despite mismatch because debug bypass is active
          .verify('example.com', [mockCert1]);
    });
  });
}
