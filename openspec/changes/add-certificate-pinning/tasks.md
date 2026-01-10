## 1. Implementation
- [ ] 1.1 Add `CertificatePinningConfig` class (support wildcards, debug flag, reportOnly) <!-- id: 1 -->
- [ ] 1.2 Add `withCertificatePinning` to `AcdcClientBuilder` <!-- id: 2 -->
- [ ] 1.5 Implement SPKI extraction utility (extract public key info from X509Certificate and SHA-256 hash it) <!-- id: 5 -->
- [ ] 1.6 Implement `PinningVerifier` class (handle wildcard matching, chain validation, configuration rules) <!-- id: 6 -->
- [ ] 1.3 Integrate certificate validation logic in Dio adapter using `PinningVerifier` <!-- id: 3 -->
- [ ] 1.4 Write integration tests with self-signed certs <!-- id: 4 -->
