import 'package:dart_acdc/src/auth/token_refresh_result.dart';
import 'package:dart_acdc/src/auth/token_refresh_strategy.dart';

/// Custom token refresh strategy wrapper.
///
/// Wraps a user-provided refresh function to implement the [TokenRefreshStrategy]
/// interface. This allows developers to provide their own token refresh logic
/// for proprietary APIs, custom authentication flows, or testing.
///
/// **Example:**
/// ```dart
/// final strategy = CustomTokenRefreshStrategy(
///   refreshFn: (refreshToken) async {
///     // Custom API call
///     final response = await myApi.refreshToken(refreshToken);
///     return TokenRefreshResult(
///       accessToken: response.accessToken,
///       refreshToken: response.newRefreshToken,
///     );
///   },
/// );
/// ```
class CustomTokenRefreshStrategy implements TokenRefreshStrategy {
  /// Creates a custom token refresh strategy.
  ///
  /// [refreshFn] is the function that performs the actual token refresh.
  /// It receives the current refresh token and must return a [TokenRefreshResult].
  ///
  /// The function may throw:
  /// - [AcdcAuthException] for authentication errors
  /// - [AcdcNetworkException] for network errors
  /// - [AcdcServerException] for server errors
  CustomTokenRefreshStrategy({
    required Future<TokenRefreshResult> Function(String) refreshFn,
  }) : _refreshFn = refreshFn;

  final Future<TokenRefreshResult> Function(String) _refreshFn;

  @override
  Future<TokenRefreshResult> refresh(String refreshToken) async =>
      _refreshFn(refreshToken);
}
