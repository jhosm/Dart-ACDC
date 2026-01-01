/// Result of a token refresh operation.
///
/// Contains the new access token and optionally a new refresh token
/// (for token rotation) and expiry times.
class TokenRefreshResult {
  /// Creates a token refresh result.
  ///
  /// [accessToken] is required. Other fields are optional:
  /// - [refreshToken]: New refresh token if rotated by the server
  /// - [accessExpiry]: Access token expiration time (UTC)
  /// - [refreshExpiry]: Refresh token expiration time (UTC)
  const TokenRefreshResult({
    required this.accessToken,
    this.refreshToken,
    this.accessExpiry,
    this.refreshExpiry,
  });

  /// The new access token.
  final String accessToken;

  /// The new refresh token (if rotated by the server).
  ///
  /// If `null`, the existing refresh token should be retained.
  final String? refreshToken;

  /// The access token expiration time in UTC.
  ///
  /// If `null`, expiry time is unknown.
  final DateTime? accessExpiry;

  /// The refresh token expiration time in UTC.
  ///
  /// If `null`, expiry time is unknown.
  final DateTime? refreshExpiry;

  @override
  String toString() => 'TokenRefreshResult('
      'hasAccessToken: ${accessToken.isNotEmpty}, '
      'hasRefreshToken: ${refreshToken != null}, '
      'accessExpiry: $accessExpiry, '
      'refreshExpiry: $refreshExpiry)';
}
