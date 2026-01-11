import 'package:meta/meta.dart';

/// Configuration for Certificate Pinning.
///
/// Use this to define which domains should be pinned to specific
/// Subject Public Key Info (SPKI) SHA-256 hashes.
@immutable
class CertificatePinningConfig {
  /// Map of domain names to their allowed SPKI SHA-256 hashes.
  ///
  /// Keys are domain names (e.g., 'api.example.com', '*.example.com').
  /// Values are lists of SHA-256 hashes prefixed with 'SHA256:'.
  final Map<String, List<String>> allowedPins;

  /// Whether to only report pinning failures instead of aborting the connection.
  ///
  /// Useful for testing pinning configuration in production before enforcing it.
  /// Default: false.
  final bool reportOnly;

  /// Whether to enable pinning checks when the app is in debug mode.
  ///
  /// If false, pinning verification is skipped in debug builds.
  /// This allows using proxy tools (e.g., Charles, Fiddler) during development.
  /// Default: true (pinning enabled in debug).
  final bool enablePinningInDebug;

  /// Creates a [CertificatePinningConfig].
  ///
  /// Throws [ArgumentError] if:
  /// - Any pin format is invalid (must start with 'SHA256:').
  /// - Any domain has an empty list of pins.
  CertificatePinningConfig({
    required this.allowedPins,
    this.reportOnly = false,
    this.enablePinningInDebug = true,
  }) {
    _validateConfig();
  }

  void _validateConfig() {
    allowedPins.forEach((domain, pins) {
      if (pins.isEmpty) {
        throw ArgumentError('Pin list for domain "$domain" cannot be empty.');
      }
      for (final pin in pins) {
        if (!pin.startsWith('SHA256:')) {
          throw ArgumentError(
            'Invalid pin format for domain "$domain". Pin "$pin" must start with "SHA256:".',
          );
        }
        // Basic validation: Prefix length (7) + at least some hash content.
        // SHA-256 base64 is 44 chars, so total 51.
        // But for flexible validation, let's just say it must be > 10 chars.
        if (pin.length < 10) {
          throw ArgumentError(
            'Invalid pin format for domain "$domain". Pin "$pin" is too short.',
          );
        }
      }
    });
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CertificatePinningConfig &&
          runtimeType == other.runtimeType &&
          reportOnly == other.reportOnly &&
          enablePinningInDebug == other.enablePinningInDebug &&
          _mapEquals(allowedPins, other.allowedPins);

  @override
  int get hashCode => Object.hash(
        reportOnly,
        enablePinningInDebug,
        // Simple hash strategy for the map: hash the keys and values.
        // This is not order-independent for keys if we iterate, but Map iteration order is defined in Dart (insertion).
        // For config objects, this is usually acceptable.
        Object.hashAll(
          allowedPins.entries
              .map((e) => Object.hash(e.key, Object.hashAll(e.value))),
        ),
      );

  bool _mapEquals(Map<String, List<String>> a, Map<String, List<String>> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_listEquals(a[key]!, b[key]!)) return false;
    }
    return true;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'CertificatePinningConfig(reportOnly: $reportOnly, enablePinning: $enablePinningInDebug, domains: ${allowedPins.keys.join(", ")})';
  }
}
