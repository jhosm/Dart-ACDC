import 'dart:async';
import 'package:dart_acdc/src/auth/backoff_manager.dart';
import 'package:dart_acdc/src/auth/custom_token_refresh_strategy.dart';
import 'package:dart_acdc/src/auth/oauth_token_refresh_strategy.dart';
import 'package:dart_acdc/src/auth/token_provider.dart';
import 'package:dart_acdc/src/auth/token_refresh_result.dart';
import 'package:dart_acdc/src/auth/token_refresh_strategy.dart';
import 'package:dart_acdc/src/exceptions/acdc_auth_exception.dart';
import 'package:dart_acdc/src/exceptions/acdc_network_exception.dart';
import 'package:dart_acdc/src/exceptions/acdc_server_exception.dart';
import 'package:dart_acdc/src/interceptors/auth_request_helper.dart';
import 'package:dio/dio.dart';

/// Interceptor that handles authentication token injection and automatic refresh.
///
/// **Features**:
/// - Automatic Bearer token injection
/// - Proactive token refresh before expiry
/// - Reactive token refresh on 401 responses
/// - Concurrent request queuing during refresh
/// - Token rotation support
/// - TokenProvider exception handling
///
/// **Interceptor Order**: Must run before ErrorInterceptor in response chain
/// to enable transparent token refresh before errors are processed.
class AuthInterceptor extends Interceptor {
  /// Creates an auth interceptor with the given configuration.
  ///
  /// [tokenProvider] is required for token management.
  ///
  /// **Token Refresh Strategy** (choose one):
  /// - [refreshStrategy]: Provide a custom [TokenRefreshStrategy] implementation
  /// - [refreshEndpointUrl] + [clientId]: Uses built-in OAuth 2.1 refresh
  /// - [customRefreshFn]: Uses custom refresh function (wrapped in strategy)
  ///
  /// [refreshThreshold] determines when to proactively refresh (default: 60s before expiry).
  /// [refreshQueueTimeout] sets the max wait time for queued requests (default: 10s).
  /// [httpClient] is optional and primarily used for testing OAuth refresh/revocation.
  ///   If not provided, a separate Dio instance will be created to avoid interceptor loops.
  AuthInterceptor({
    required TokenProvider tokenProvider,
    TokenRefreshStrategy? refreshStrategy,
    String? refreshEndpointUrl,
    String? clientId,
    Future<TokenRefreshResult> Function(String)? customRefreshFn,
    Duration refreshThreshold = const Duration(seconds: 60),
    Duration refreshQueueTimeout = const Duration(seconds: 10),
    Dio? httpClient,
  })  : _tokenProvider = tokenProvider,
        _refreshThreshold = refreshThreshold,
        _refreshQueueTimeout = refreshQueueTimeout {
    // Validate configuration
    if (refreshThreshold.inSeconds <= 0) {
      throw ArgumentError('refreshThreshold must be positive');
    }

    // Determine and set the refresh strategy
    if (refreshStrategy != null) {
      _refreshStrategy = refreshStrategy;
    } else if (refreshEndpointUrl != null && clientId != null) {
      _refreshStrategy = OAuthTokenRefreshStrategy(
        refreshEndpointUrl: refreshEndpointUrl,
        clientId: clientId,
        httpClient: httpClient,
      );
    } else if (customRefreshFn != null) {
      _refreshStrategy = CustomTokenRefreshStrategy(
        refreshFn: customRefreshFn,
      );
    } else {
      throw ArgumentError(
        'Either refreshStrategy, refreshEndpointUrl+clientId, OR customRefreshFn must be provided',
      );
    }
  }

  final TokenProvider _tokenProvider;
  late final TokenRefreshStrategy _refreshStrategy;
  final Duration _refreshThreshold;
  final Duration _refreshQueueTimeout;

  // Refresh state management
  Completer<void>? _refreshCompleter;
  bool _isRefreshing = false;
  final _backoffManager = BackoffManager();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip if Authorization header already exists (manual override)
    if (AuthRequestHelper.hasManualAuthHeader(options)) {
      handler.next(options);
      return;
    }

    try {
      // Retrieve access token and expiry
      final accessToken = await _tokenProvider.getAccessToken();

      // No token available - proceed without auth
      if (accessToken == null) {
        handler.next(options);
        return;
      }

      // Check if token needs proactive refresh
      final needsRefresh = await _needsProactiveRefresh();
      if (needsRefresh) {
        // Refresh token before proceeding
        await _refreshTokenWithQueue();

        // Get the new token after refresh
        final newToken = await _tokenProvider.getAccessToken();
        if (newToken != null) {
          AuthRequestHelper.injectBearerToken(options, newToken);
        }
      } else {
        // Token is valid, inject it
        AuthRequestHelper.injectBearerToken(options, accessToken);
      }

      handler.next(options);
    } on Exception {
      // TokenProvider.getAccessToken() threw exception
      // Log error and proceed without auth
      // TODO(auth): Add logging when logging interceptor is implemented
      handler.next(options);
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Only handle 401 Unauthorized responses
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    // Check if this is a retry after refresh (prevent infinite loop)
    if (AuthRequestHelper.isRetryRequest(err.requestOptions)) {
      // Second 401 after refresh - clear tokens and fail
      await _clearTokensSafely();
      handler.next(
        AcdcAuthException.fromDioException(
          err,
          message: 'Authentication failed after token refresh',
        ),
      );
      return;
    }

    try {
      // Attempt token refresh
      await _refreshTokenWithQueue();

      // Get new access token
      final newToken = await _tokenProvider.getAccessToken();
      if (newToken == null) {
        // No token after refresh - fail
        handler.next(
          AcdcAuthException.fromDioException(
            err,
            message: 'No access token available after refresh',
          ),
        );
        return;
      }

      // Retry the original request with new token
      final requestOptions = err.requestOptions;
      AuthRequestHelper.injectBearerToken(requestOptions, newToken);
      AuthRequestHelper.markAsRetry(requestOptions);

      // Make the retry request
      final dio = Dio();
      final response = await dio.fetch<dynamic>(requestOptions);
      handler.resolve(response);
    } on DioException catch (e) {
      // Refresh failed - pass error through
      handler.next(e);
    } on Exception {
      // Non-DioException error - pass original error through
      handler.next(err);
    }
  }

  /// Checks if proactive token refresh is needed.
  Future<bool> _needsProactiveRefresh() async {
    try {
      final expiry = await _tokenProvider.getAccessTokenExpiry();

      // No expiry info - rely on reactive refresh
      if (expiry == null) {
        return false;
      }

      // Check if token expires within threshold
      final now = DateTime.now().toUtc();
      final timeUntilExpiry = expiry.difference(now);

      return timeUntilExpiry <= _refreshThreshold;
    } on Exception {
      // Exception from getAccessTokenExpiry - skip proactive refresh
      return false;
    }
  }

  /// Refreshes the token with concurrent request queuing.
  Future<void> _refreshTokenWithQueue() async {
    // If refresh is already in progress, wait for it
    if (_isRefreshing) {
      final completer = _refreshCompleter;
      if (completer != null) {
        await completer.future.timeout(
          _refreshQueueTimeout,
          onTimeout: () {
            throw AcdcAuthException(
              requestOptions: AuthRequestHelper.createEmptyRequestOptions(),
              message: 'Token refresh timeout',
            );
          },
        );
      }
      return;
    }

    // Start new refresh
    _isRefreshing = true;
    _refreshCompleter = Completer<void>();
    // Prevent unhandled exception if no one awaits the future when error is completed
    unawaited(_refreshCompleter!.future.catchError((_) {}));

    try {
      await _performTokenRefresh();
      _refreshCompleter?.complete();
    } catch (e) {
      _refreshCompleter?.completeError(e);
      rethrow;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }

  /// Performs the actual token refresh operation.
  Future<void> _performTokenRefresh() async {
    try {
      // Wait for exponential backoff if needed
      await _backoffManager.waitIfNeeded();

      // Get refresh token
      String? refreshToken;
      try {
        refreshToken = await _tokenProvider.getRefreshToken();
      } on Exception catch (e) {
        throw AcdcAuthException(
          requestOptions: AuthRequestHelper.createEmptyRequestOptions(),
          message: 'Failed to retrieve refresh token: $e',
        );
      }

      if (refreshToken == null) {
        throw AcdcAuthException(
          requestOptions: AuthRequestHelper.createEmptyRequestOptions(),
          message: 'No refresh token available',
        );
      }

      // Check if refresh token is expired
      DateTime? refreshExpiry;
      try {
        refreshExpiry = await _tokenProvider.getRefreshTokenExpiry();
      } on Exception {
        // Ignore expiry check errors, proceed with refresh
      }

      if (refreshExpiry != null &&
          refreshExpiry.isBefore(DateTime.now().toUtc())) {
        await _clearTokensSafely();
        throw AcdcAuthException(
          requestOptions: AuthRequestHelper.createEmptyRequestOptions(),
          message: 'Refresh token expired. Please log in again.',
        );
      }

      // Perform refresh using the strategy
      final result = await _refreshStrategy.refresh(refreshToken);

      // Store new tokens
      try {
        await _tokenProvider.setTokens(
          accessToken: result.accessToken,
          refreshToken: result.refreshToken,
          accessExpiry: result.accessExpiry,
          refreshExpiry: result.refreshExpiry,
        );
      } on Exception catch (e) {
        throw AcdcAuthException(
          requestOptions: AuthRequestHelper.createEmptyRequestOptions(),
          message: 'Failed to store refreshed tokens: $e',
        );
      }

      // Reset backoff on success
      _backoffManager.reset();
    } on AcdcAuthException {
      // Auth errors - clear tokens
      await _clearTokensSafely();
      rethrow;
    } on AcdcNetworkException {
      // Network errors - don't clear tokens
      rethrow;
    } on AcdcServerException {
      // Server errors - apply exponential backoff
      _backoffManager.increment();
      rethrow;
    }
  }

  /// Safely clears tokens, catching exceptions.
  Future<void> _clearTokensSafely() async {
    try {
      await _tokenProvider.clearTokens();
    } on Exception {
      // Log warning and continue
      // TODO(auth): Add logging when logging interceptor is implemented
    }
  }

  /// Cancels any in-progress refresh operation.
  void cancelRefresh() {
    if (_isRefreshing && _refreshCompleter != null) {
      _refreshCompleter!.completeError(
        AcdcAuthException(
          requestOptions: AuthRequestHelper.createEmptyRequestOptions(),
          message: 'Token refresh cancelled',
        ),
      );
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }
}
