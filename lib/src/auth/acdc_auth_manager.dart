import 'package:dart_acdc/src/auth/token_provider.dart';
import 'package:dart_acdc/src/cache/acdc_cache_manager.dart';
import 'package:dart_acdc/src/cache/jwt_utils.dart';
import 'package:dart_acdc/src/interceptors/auth_interceptor.dart';
import 'package:dio/dio.dart';

/// Manager for authentication operations.
///
/// Provides methods for:
/// - Logging out with token revocation
/// - Forcing token refresh
/// - Detecting user changes and clearing cache
///
/// Accessible via `dio.auth` extension.
class AcdcAuthManager {
  /// Internal constructor.
  ///
  /// Use the `AcdcAuth` extension to access the manager: `dio.auth`
  /// [httpClient] is optional and primarily used for testing token revocation.
  /// [cacheManager] is optional - when provided, enables cache clearing during logout.
  AcdcAuthManager({
    TokenProvider? tokenProvider,
    AuthInterceptor? authInterceptor,
    String? revocationEndpointUrl,
    String? clientId,
    AcdcCacheManager? cacheManager,
    Dio? httpClient,
  })  : _tokenProvider = tokenProvider,
        _authInterceptor = authInterceptor,
        _revocationEndpointUrl = revocationEndpointUrl,
        _clientId = clientId,
        _cacheManager = cacheManager,
        _httpClient = httpClient {
    // Track initial user ID for user change detection
    if (_tokenProvider != null) {
      _initializeUserTracking();
    }
  }

  final TokenProvider? _tokenProvider;
  final AuthInterceptor? _authInterceptor;
  final String? _revocationEndpointUrl;
  final String? _clientId;
  final AcdcCacheManager? _cacheManager;
  final Dio? _httpClient;

  /// Returns true if authentication is configured (TokenProvider is present).
  bool get isConfigured => _tokenProvider != null;

  /// Cached user ID for detecting user changes
  String? _currentUserId;

  /// Initialize user tracking by extracting current user ID.
  void _initializeUserTracking() {
    // Extract user ID asynchronously
    _updateCurrentUserId();
  }

  /// Updates the cached user ID from the current access token.
  Future<void> _updateCurrentUserId() async {
    try {
      if (_tokenProvider != null) {
        final accessToken = await _tokenProvider!.getAccessToken();
        if (accessToken != null) {
          _currentUserId = JwtUtils.extractUserId(accessToken);
        }
      }
    } on Exception catch (_) {
      // Ignore errors - user tracking is best-effort
    }
  }

  /// Checks if the user has changed and clears cache if so.
  ///
  /// This is called internally after token refresh or login.
  Future<void> _checkUserChangeAndClearCache() async {
    final previousUserId = _currentUserId;
    await _updateCurrentUserId();

    // If user changed, clear cache
    if (previousUserId != null &&
        _currentUserId != null &&
        previousUserId != _currentUserId) {
      await _clearCache();
    }
  }

  /// Logs out the user by revoking tokens and clearing local storage.
  ///
  /// **Steps**:
  /// 1. Cancels any in-progress token refresh
  /// 2. Clears cached responses (user-isolated cache)
  /// 3. Revokes refresh token (if revocation endpoint configured)
  /// 4. Revokes access token (if revocation endpoint configured)
  /// 5. Clears tokens from local storage
  /// 6. Resets user tracking
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
    if (_authInterceptor != null) {
      _authInterceptor!.cancelRefresh();
    }

    // Clear cache before clearing tokens (cache needs user ID)
    await _clearCache();

    // Revoke tokens if endpoint is configured
    if (_revocationEndpointUrl != null && _clientId != null) {
      await _revokeTokens();
    }

    // Clear tokens from local storage
    if (_tokenProvider != null) {
      try {
        await _tokenProvider!.clearTokens();
      } on Exception {
        // Log warning but continue - storage might have failed but logout succeeds
        // TODO(auth): Add logging when logging interceptor is implemented
      }
    }

    // Reset user tracking
    _currentUserId = null;
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
    if (_authInterceptor == null) {
      throw StateError('Authentication is disabled. Cannot refresh tokens.');
    }
    // Trigger refresh through the auth interceptor
    // This reuses the same refresh logic and queuing mechanism
    final options = RequestOptions(path: '/refresh-trigger');
    await _authInterceptor!.onRequest(
      options,
      RequestInterceptorHandler(),
    );
  }

  /// Internal helper to clear cache using the manager
  Future<void> _clearCache() async {
    if (_cacheManager != null) {
      await _cacheManager!.clearCache();
    }
  }

  /// Checks for user changes after token operations.
  ///
  /// Should be called after login or token refresh to detect if the user
  /// has changed and clear cache accordingly.
  ///
  /// This is primarily for internal use but exposed for testing.
  Future<void> checkUserChange() async {
    await _checkUserChangeAndClearCache();
  }

  /// Revokes both refresh and access tokens.
  Future<void> _revokeTokens() async {
    final revocationUrl = _revocationEndpointUrl!;
    final clientId = _clientId!;

    // Get tokens before revoking
    String? refreshToken;
    String? accessToken;
    try {
      if (_tokenProvider != null) {
        refreshToken = await _tokenProvider!.getRefreshToken();
        accessToken = await _tokenProvider!.getAccessToken();
      }
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
/// Provides access to auth operations like logout and refresh.
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
