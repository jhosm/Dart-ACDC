# security Specification

## Purpose
TBD - created by archiving change add-certificate-pinning. Update Purpose after archive.
## Requirements
### Requirement: Certificate Pinning
The library SHALL support SSL/TLS certificate pinning to prevent Man-in-the-Middle (MitM) attacks.

#### Scenario: Valid certificate pin
- **WHEN** a request is made to a domain with a pinned certificate
- **AND** the server presents a certificate whose Subject Public Key Info (SPKI) matches the pinned SHA-256 hash
- **THEN** the interaction proceeds normally
- **AND** the connection is established
- **AND** the connection is established
- **AND** pinning SPKI allows certificate rotation without client updates (as long as the key pair remains the same)
- **AND** the check passes if ANY certificate in the server's chain matches ANY of the configured pins for that domain

#### Scenario: Basic TLS validation prerequisites
- **WHEN** pinning is configured
- **THEN** basic TLS checks MUST pass first:
  - Certificate MUST NOT be expired
  - Certificate hostname MUST match the request host
  - Certificate MUST NOT be malformed
- **AND** if these checks fail, the connection aborts regardless of pins
- **AND** this applies even for self-signed certificates (they must be valid for the date and host)

#### Scenario: Trust validation override
- **WHEN** basic TLS checks pass
- **THEN** the Trust decision is made:
  - SYSTEM TRUST: Certificate is chained to a Root CA in the OS store
  - PINNED TRUST: Certificate (or parent) SPKI matches a configured pin AND parent-child signatures are valid
- **AND** if EITHER System Trust OR Pinned Trust is established, the connection proceeds
- **AND** this enables support for self-signed certificates (Pinned Trust) without disabling security

#### Scenario: Report-Only mode
- **WHEN** `reportOnly: true` is configured
- **AND** a request creates a pinning failure (mismatch)
- **THEN** the connection IS ESTABLISHED (if standard trust works) OR ABORTED (if standard trust fails)
- **AND** an `onPinningFailure` callback is invoked with details
- **AND** no `AcdcSecurityException` is thrown for the pin mismatch itself
- **AND** this allows safely collecting data on pinning violations before enforcement

#### Scenario: Empty pin list
- **WHEN** a domain is configured with an empty list of pins
- **THEN** initialization fails with an `ArgumentError`
- **AND** pinning configuration MUST include at least one pin per domain

#### Scenario: Pin format validation
- **WHEN** configuring pins
- **THEN** pins MUST match the format `SHA256:<base64-encoded-hash>`
- **AND** initialization fails with an `ArgumentError` if format is invalid
- **AND** invalid characters or incorrect length cause immediate failure

#### Scenario: Exception details
- **WHEN** a pinning failure occurs
- **THEN** the `AcdcSecurityException` includes the hostname
- **AND** includes the list of SHA-256 hashes from the server's certificate chain (peer + intermediates)
- **AND** this helps developers identify the correct pin to trust during debugging

#### Scenario: Wildcard domain support
- **WHEN** a pin is configured for `*.example.com`
- **AND** a request is made to `api.example.com` or `auth.example.com`
- **THEN** the server certificate is validated against the wildcard pin
- **AND** `example.com` (root) is NOT matched by `*.example.com` (consistent with standard SSL matching)

#### Scenario: Debug bypass
- **WHEN** the app is running in debug mode (e.g., local development with proxy)
- **AND** `enablePinningInDebug` is set to `false` (default: true)
- **THEN** certificate pinning verification is skipped
- **AND** this allows using tools like Charles Proxy or Fiddler

#### Scenario: Backup pins
- **WHEN** configuring pins
- **THEN** the library MUST require or strongly validate that at least two pins are provided per domain
- **AND** this prevents app bricking if keys are compromised or rotated unexpectedly

#### Scenario: Invalid certificate pin
- **WHEN** a request is made to a domain with a pinned certificate
- **AND** the server presents a certificate that does NOT match the pinned hash
- **THEN** the connection is immediately aborted
- **AND** an `AcdcSecurityException` is thrown
- **AND** no data is sent to the server

#### Scenario: Unpinned domain
- **WHEN** a request is made to a domain without configured pins
- **THEN** standard system trust store validation is used
- **AND** connection proceeds if the CA is trusted by the OS

#### Scenario: Configuration
- **WHEN** configuring certificate pinning
- **THEN** developers provide a map of domain names to lists of allowed SHA-256 fingerprints
- **AND** multiple pins can be provided per domain (for backup keys)

```dart
final dio = AcdcClientBuilder()
  .withCertificatePinning({
    'api.example.com': [
      'SHA256:abc123...', 
      'SHA256:def456...' 
    ]
  })
  .build();
```

