# Certificate Pinning

Certificate pinning defends against Man-in-the-Middle (MITM) attacks by verifying that the server presents a specific public key certificate.

## Configuration

Pinning is configured via the `CertificatePinningConfig` object. You provide SHA-256 hashes of the Subject Public Key Info (SPKI).

```dart
import 'package:dart_acdc/dart_acdc.dart';

final dio = AcdcClientBuilder()
    .withCertificatePinning(CertificatePinningConfig(
      pins: {
        'api.example.com': [
          'SHA-256-HASH-OF-YOUR-CERT-SPKI',
          'BACKUP-SHA-256-HASH',
        ],
      },
      // Optional: Report failures without blocking requests (for testing)
      reportOnly: false, 
      
      // Optional callback for failures
      onPinningFailure: (host, cert, expectedPins) {
        print('Security Alert! Pinning failed for $host');
      },
    ))
    .build();
```

## Obtaining Pins

You can extract SPKI hashes using OpenSSL:

```bash
openssl s_client -connect api.example.com:443 | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64
```

## Behavior

-   **Enforced**: By default, if the server's certificate chain doesn't match any of the provided pins, the connection is terminated instantly. An `AcdcSecurityException` is thrown.
-   **Report Only**: If `reportOnly: true`, the connection proceeds even if pinning fails, but `onPinningFailure` is called. This is useful for safely rolling out pinning.

## Platform Support

This feature relies on Dart's `SecurityContext` and is supported on mobile (iOS/Android) and desktop platforms. It does **not** work on Flutter Web (which relies on the browser's trust store).
