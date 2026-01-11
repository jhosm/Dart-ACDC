import 'package:dart_acdc/src/security/certificate_pinning_config.dart';
import 'package:test/test.dart';

void main() {
  group('CertificatePinningConfig', () {
    test('creates valid config', () {
      final config = CertificatePinningConfig(
        allowedPins: {
          'example.com': ['SHA256:abc1234567'],
          'api.example.com': ['SHA256:def4567890'],
        },
      );

      expect(config.allowedPins.length, 2);
      expect(config.reportOnly, isFalse);
      expect(config.enablePinningInDebug, isTrue);
    });

    test('creates valid config with custom flags', () {
      final config = CertificatePinningConfig(
        allowedPins: {
          'example.com': ['SHA256:abc1234567'],
        },
        reportOnly: true,
        enablePinningInDebug: false,
      );

      expect(config.reportOnly, isTrue);
      expect(config.enablePinningInDebug, isFalse);
    });

    test('throws ArgumentError when pin list is empty', () {
      expect(
        () => CertificatePinningConfig(
          allowedPins: {
            'example.com': [],
          },
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when pin format is invalid (missing prefix)',
        () {
      expect(
        () => CertificatePinningConfig(
          allowedPins: {
            'example.com': ['abc1234567'],
          },
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when pin is too short', () {
      expect(
        () => CertificatePinningConfig(
          allowedPins: {
            'example.com': ['SHA256:a'],
          },
        ),
        throwsArgumentError,
      );
    });

    test('equality checks work', () {
      final config1 = CertificatePinningConfig(
        allowedPins: {
          'example.com': ['SHA256:abc'],
        },
      );
      final config2 = CertificatePinningConfig(
        allowedPins: {
          'example.com': ['SHA256:abc'],
        },
      );
      final config3 = CertificatePinningConfig(
        allowedPins: {
          'other.com': ['SHA256:abc'],
        },
      );

      expect(config1, equals(config2));
      expect(config1.hashCode, equals(config2.hashCode));
      expect(config1, isNot(equals(config3)));
    });

    test('toString returns meaningful string', () {
      final config = CertificatePinningConfig(
        allowedPins: {
          'example.com': ['SHA256:abc'],
        },
      );
      expect(config.toString(), contains('example.com'));
      expect(config.toString(), contains('CertificatePinningConfig'));
    });
  });
}
