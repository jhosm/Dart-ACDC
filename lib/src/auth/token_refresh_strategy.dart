import 'package:dart_acdc/src/auth/token_refresh_result.dart';
import 'package:dart_acdc/src/exceptions/acdc_auth_exception.dart';
import 'package:dart_acdc/src/exceptions/acdc_network_exception.dart';
import 'package:dart_acdc/src/exceptions/acdc_server_exception.dart';

/// Strategy interface for token refresh operations.
///
/// Implementations of this interface define how refresh tokens are exchanged
/// for new access tokens. This allows for different refresh mechanisms:
/// - OAuth 2.1 token refresh via HTTP requests
/// - Custom refresh logic (e.g., proprietary APIs, local token generation)
/// - Mock implementations for testing
///
/// **Usage:**
/// ```dart
/// // OAuth strategy
/// final strategy = OAuthTokenRefreshStrategy(
///   refreshEndpointUrl: 'https://auth.example.com/token',
///   clientId: 'my-client-id',
/// );
///
/// // Custom strategy
/// final strategy = CustomTokenRefreshStrategy(
///   refreshFn: (refreshToken) async {
///     // Custom refresh logic
///     return TokenRefreshResult(accessToken: 'new-token');
///   },
/// );
/// ```
// ignore: one_member_abstracts
abstract class TokenRefreshStrategy {
  /// Refreshes the access token using the provided refresh token.
  ///
  /// [refreshToken] is the current refresh token to exchange for a new access token.
  ///
  /// Returns a [TokenRefreshResult] containing:
  /// - `accessToken`: The new access token (required)
  /// - `refreshToken`: New refresh token if rotated (optional)
  /// - `accessExpiry`: Expiry time for the access token (optional)
  /// - `refreshExpiry`: Expiry time for the refresh token (optional)
  ///
  /// **Exceptions:**
  /// - [AcdcAuthException]: Authentication errors (invalid tokens, auth failures)
  /// - [AcdcNetworkException]: Network connectivity issues
  /// - [AcdcServerException]: Server errors (5xx responses)
  Future<TokenRefreshResult> refresh(String refreshToken);
}
