## 1. Implementation
- [x] 1.1 Add `CertificatePinningConfig` class (support wildcards, debug flag, reportOnly) <!-- id: 1 -->
- [x] 1.2 Add `withCertificatePinning` to `AcdcClientBuilder` <!-- id: 2 -->
- [x] 1.5 Implement SPKI extraction utility (extract public key info from X509Certificate and SHA-256 hash it) <!-- id: 5 -->
- [x] 1.6 Implement `PinningVerifier` class (handle wildcard matching, chain validation, configuration rules) <!-- id: 6 -->
- [x] 1.3 Integrate certificate validation logic in Dio adapter using `PinningVerifier` <!-- id: 3 -->
- [x] 1.4 Write integration tests with self-signed certs <!-- id: 4 -->
