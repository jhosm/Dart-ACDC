import 'dart:io';

import 'package:dart_acdc/src/exceptions/acdc_security_exception.dart';
import 'package:dart_acdc/src/security/certificate_pinning_config.dart';
import 'package:dart_acdc/src/security/spki_util.dart';
import 'package:dio/dio.dart';

/// Verifies server certificates against a trusted set of pins.
class PinningVerifier {
  final CertificatePinningConfig _config;

  /// Callback for report-only mode failures.
  final void Function(AcdcSecurityException exception)? onPinningFailure;

  /// Function to extract SPKI hash from a certificate. Check [SpkiUtil.extractSpkiHash].
  /// Exposed for testing.
  final String Function(X509Certificate) spkiExtractor;

  PinningVerifier(
    this._config, {
    this.onPinningFailure,
    String Function(X509Certificate)? spkiExtractor,
  }) : spkiExtractor = spkiExtractor ?? SpkiUtil.extractSpkiHash;

  /// Verifies the [hostname] and [chain] against the configuration.
  ///
  /// Throws [AcdcSecurityException] if pinning fails and not in report-only mode.
  /// Returns normally if verification succeeds or is skipped.
  void verify(String hostname, List<X509Certificate> chain) {
    // 1. Check Debug Bypass
    // Note: We need a way to detect debug mode.
    // Ideally, we consistently use `kDebugMode` or `assert`.
    // Here we will use `assert` trick since we are in pure Dart mostly.
    bool splitDebug = false;
    assert(() {
      splitDebug = true;
      return true;
    }());

    if (splitDebug && !_config.enablePinningInDebug) {
      return;
    }

    // 2. Find matching pins
    final matchedPins = _findPinsForHost(hostname);
    if (matchedPins == null || matchedPins.isEmpty) {
      // Domain not pinned, proceed with standard trust (handled by OS/HttpClient)
      return;
    }

    // 3. Verify Chain
    // Calculate SPKI hashes for the chain
    final peerSpkiHashes = <String>[];
    for (final cert in chain) {
      try {
        final hash = spkiExtractor(cert);
        peerSpkiHashes.add(hash);

        // Check if this hash is in our allowed list
        if (matchedPins.contains(hash)) {
          // Success! A cert in the chain is trusted.
          return;
        }
      } catch (e) {
        // If we can't extract hash, we can't verify this cert. Continue to next.
        // If all fail, we will reject.
        continue;
      }
    }

    // 4. Failure Handling
    final exception = AcdcSecurityException(
      requestOptions: RequestOptions(path: hostname), // Minimal info
      hostname: hostname,
      message:
          'Certificate pinning failure: No matching pin found for $hostname',
      peerCertificates: peerSpkiHashes,
    );

    if (_config.reportOnly) {
      onPinningFailure?.call(exception);
    } else {
      throw exception;
    }
  }

  /// Finds configured pins for the given [hostname], handling wildcards.
  List<String>? _findPinsForHost(String hostname) {
    // 1. Exact match
    if (_config.allowedPins.containsKey(hostname)) {
      return _config.allowedPins[hostname];
    }

    // 2. Wildcard match
    // Spec: *.example.com matches api.example.com but NOT example.com or a.b.example.com
    // We iterate keys to find applicable wildcards.
    for (final key in _config.allowedPins.keys) {
      if (key.startsWith('*.')) {
        final domainPart = key.substring(2); // remove *.
        final hostParts = hostname.split('.');
        final domainParts = domainPart.split('.');

        // Host must end with domain part
        if (!hostname.endsWith(domainPart)) continue;

        // Host must have exactly one more label than domain part
        // e.g. host: a.example.com (3 parts), domain: example.com (2 parts) -> diff is 1.
        // host: a.b.example.com (4 parts) -> diff is 2 (NO match for *.)
        if (hostParts.length == domainParts.length + 1) {
          return _config.allowedPins[key];
        }
      }
    }

    return null;
  }
}
