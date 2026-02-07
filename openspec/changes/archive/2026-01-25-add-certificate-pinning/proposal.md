# Change: Add Certificate Pinning

## Why
Mobile applications accessing sensitive APIs need protection against Man-in-the-Middle (MitM) attacks where an attacker presents a valid but unauthorized certificate. Certificate pinning ensures the app only connects to servers presenting a specific known certificate or public key.

## What Changes
- Add `withCertificatePinning` method to `AcdcClientBuilder`
- Validate server certificates against pinned hashes (SPKI)
- Support wildcard domains
- Add debug bypass option
- Use Dio's `BadCertificateCallback` or `HttpClientAdapter` configuration
- Support SHA-256 fingerprinting

## Impact
- Affected specs: `security` (new)
- Affected code: `AcdcClientBuilder`, `Dio` configuration
