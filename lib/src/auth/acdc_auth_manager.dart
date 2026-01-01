import 'package:dart_acdc/src/auth/token_provider.dart';
import 'package:dart_acdc/src/interceptors/auth_interceptor.dart';
import 'package:dio/dio.dart';

/// Manager for authentication operations.
///
/// Provides methods for:
/// - Logging out with token revocation
/// - Forcing token refresh
/// - Clearing cached responses
///
/// Accessible via `dio.auth` extension.
class AcdcAuthManager {

  /// Internal constructor.
  ///
  /// Use the `AcdcAuth` extension to access the manager: `dio.auth`
  /// [httpClient] is optional and primarily used for testing token revocation.
  AcdcAuthManager({
    required TokenProvider tokenProvider,
    required AuthInterceptor authInterceptor,
    String? revocationEndpointUrl,
    String? clientId,
    Dio? httpClient,
  })  : _tokenProvider = tokenProvider,
        _authInterceptor = authInterceptor,
        _revocationEndpointUrl = revocationEndpointUrl,
        _clientId = clientId,
        _httpClient = httpClient;
  final TokenProvider _tokenProvider;
  final AuthInterceptor _authInterceptor;
  final String? _revocationEndpointUrl;
  final String? _clientId;
  final Dio? _httpClient;

  /// Logs out the user by revoking tokens and clearing local storage.
  ///
  /// **Steps**:
  /// 1. Cancels any in-progress token refresh
  /// 2. Revokes refresh token (if revocation endpoint configured)
  /// 3. Revokes access token (if revocation endpoint configured)
  /// 4. Clears tokens from local storage
  ///
  /// **Best-effort revocation**: Even if revocation requests fail,
  /// tokens are still cleared locally and logout completes successfully.
  ///
  /// **Usage**:
  /// ```dart
  /// await dio.auth.logout();
  /// // User is now logged out, redirect to login screen
  /// ```
  Future<void> logout() async {
    // Cancel any in-progress refresh
    _authInterceptor.cancelRefresh();

    // Revoke tokens if endpoint is configured
    if (_revocationEndpointUrl != null && _clientId != null) {
      await _revokeTokens();
    }

    // Clear tokens from local storage
    try {
      await _tokenProvider.clearTokens();
    } on Exception {
      // Log warning but continue - storage might have failed but logout succeeds
      // TODO(auth): Add logging when logging interceptor is implemented
    }
  }

  /// Forces an immediate token refresh.
  ///
  /// **When to use**: Typically not needed - the auth interceptor handles
  /// refresh automatically. Use only when you need to ensure tokens are
  /// fresh before a specific operation.
  ///
  /// **Behavior**:
  /// - Triggers token refresh immediately
  /// - Throws exception if refresh fails
  /// - Updates stored tokens on success
  ///
  /// **Usage**:
  /// ```dart
  /// try {
  ///   await dio.auth.refreshNow();
  ///   // Tokens are now refreshed
  /// } catch (e) {
  ///   // Handle refresh failure
  /// }
  /// ```
  Future<void> refreshNow() async {
    // Trigger refresh through the auth interceptor
    // This reuses the same refresh logic and queuing mechanism
    final options = RequestOptions(path: '/refresh-trigger');
    await _authInterceptor.onRequest(
      options,
      RequestInterceptorHandler(),
    );
  }

  /// Clears all cached HTTP responses.
  ///
  /// **When to use**:
  /// - After logout to remove user-specific cached data
  /// - When you need to force fresh data from the server
  /// - After user changes (e.g., account switching)
  ///
  /// **Usage**:
  /// ```dart
  /// await dio.auth.clearCache();
  /// // All cached responses have been cleared
  /// ```
  Future<void> clearCache() async {
    // Clear cache by removing the cache store
    // This will be implemented when cache interceptor is added
    // TODO(cache): Implement cache clearing when cache interceptor is ready
  }

  /// Revokes both refresh and access tokens.
  Future<void> _revokeTokens() async {
    final revocationUrl = _revocationEndpointUrl!;
    final clientId = _clientId!;

    // Get tokens before revoking
    String? refreshToken;
    String? accessToken;
    try {
      refreshToken = await _tokenProvider.getRefreshToken();
      accessToken = await _tokenProvider.getAccessToken();
    } on Exception {
      // If we can't get tokens, skip revocation (best-effort)
      return;
    }

    // Revoke refresh token first (higher priority)
    if (refreshToken != null) {
      await _revokeToken(
        revocationUrl,
        clientId,
        refreshToken,
        'refresh_token',
      );
    }

    // Then revoke access token
    if (accessToken != null) {
      await _revokeToken(
        revocationUrl,
        clientId,
        accessToken,
        'access_token',
      );
    }
  }

  /// Revokes a single token.
  Future<void> _revokeToken(
    String revocationUrl,
    String clientId,
    String token,
    String tokenTypeHint,
  ) async {
    try {
      // Use injected client or create a separate instance to avoid interceptor loops
      final dio = _httpClient ?? Dio();
      await dio.post<void>(
        revocationUrl,
        data: {
          'token': token,
          'token_type_hint': tokenTypeHint,
          'client_id': clientId,
        },
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          headers: {'Accept': 'application/json'},
        ),
      );
    } on DioException {
      // Best-effort revocation - log warning but don't fail logout
      // TODO(auth): Add logging when logging interceptor is implemented
    }
  }
}

/// Extension on [Dio] to access authentication manager.
///
/// Provides access to auth operations like logout, refresh, and cache clearing.
///
/// **Usage**:
/// ```dart
/// final dio = AcdcClientBuilder()
///   .withTokenProvider(myTokenProvider)
///   .withTokenRefreshEndpoint(...)
///   .build();
///
/// // Access auth manager
/// await dio.auth.logout();
/// await dio.auth.refreshNow();
/// await dio.auth.clearCache();
/// ```
extension AcdcAuth on Dio {
  /// Gets the authentication manager for this Dio instance.
  ///
  /// **Throws**: [StateError] if no TokenProvider was configured.
  AcdcAuthManager get auth {
    final manager = options.extra['_acdc_auth_manager'] as AcdcAuthManager?;
    if (manager == null) {
      throw StateError(
        'No TokenProvider configured. Use AcdcClientBuilder.withTokenProvider() '
        'to enable authentication.',
      );
    }
    return manager;
  }
}
