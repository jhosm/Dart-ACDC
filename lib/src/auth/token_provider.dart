/// Interface for managing authentication tokens.
///
/// Implementations should securely store tokens using platform-specific
/// mechanisms like iOS Keychain or Android Keystore.
///
/// The provider stores tokens without validating expiry - expiry validation
/// is handled by the auth interceptor.
abstract class TokenProvider {
  /// Retrieves the current access token.
  ///
  /// Returns `null` if no access token is available.
  Future<String?> getAccessToken();

  /// Retrieves the current refresh token.
  ///
  /// Returns `null` if no refresh token is available.
  Future<String?> getRefreshToken();

  /// Retrieves the access token expiry time in UTC.
  ///
  /// Returns `null` if expiry is not known or not tracked.
  /// This enables proactive token refresh.
  Future<DateTime?> getAccessTokenExpiry();

  /// Retrieves the refresh token expiry time in UTC.
  ///
  /// Returns `null` if expiry is not known or not tracked.
  Future<DateTime?> getRefreshTokenExpiry();

  /// Stores new authentication tokens.
  ///
  /// [accessToken] is required and always updated. Other parameters are optional:
  /// - [refreshToken]: New refresh token (required for token rotation).
  ///   When `null`, implementations MUST preserve the existing refresh token.
  /// - [accessExpiry]: Access token expiration time (UTC).
  ///   When non-null, this MUST overwrite any previously stored access-token expiry.
  ///   When `null`, implementations MUST treat the access-token expiry as unknown
  ///   (i.e. clear any previously stored expiry rather than preserving it).
  /// - [refreshExpiry]: Refresh token expiration time (UTC).
  ///   When non-null, this MUST overwrite any previously stored refresh-token expiry.
  ///   When `null`, implementations MUST treat the refresh-token expiry as unknown
  ///   (i.e. clear any previously stored expiry rather than preserving it).
  ///
  /// This enables partial updates like refreshing only the access token without
  /// rotating the refresh token, while still allowing expiry to be cleared by
  /// passing `null`.
  Future<void> setTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? accessExpiry,
    DateTime? refreshExpiry,
  });

  /// Clears all stored tokens.
  ///
  /// Called during logout or when tokens are invalidated.
  Future<void> clearTokens();
}
