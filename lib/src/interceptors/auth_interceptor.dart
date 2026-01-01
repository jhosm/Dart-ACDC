import 'dart:async';
import 'package:dart_acdc/src/auth/token_provider.dart';
import 'package:dart_acdc/src/auth/token_refresh_result.dart';
import 'package:dart_acdc/src/exceptions/acdc_auth_exception.dart';
import 'package:dart_acdc/src/exceptions/acdc_network_exception.dart';
import 'package:dart_acdc/src/exceptions/acdc_server_exception.dart';
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
  /// Either [refreshEndpointUrl] + [clientId] OR [customRefreshFn] must be provided.
  /// [refreshThreshold] determines when to proactively refresh (default: 60s before expiry).
  /// [refreshQueueTimeout] sets the max wait time for queued requests (default: 10s).
  /// [httpClient] is optional and primarily used for testing OAuth refresh/revocation.
  ///   If not provided, a separate Dio instance will be created to avoid interceptor loops.
  AuthInterceptor({
    required TokenProvider tokenProvider,
    String? refreshEndpointUrl,
    String? clientId,
    Future<TokenRefreshResult> Function(String)? customRefreshFn,
    Duration refreshThreshold = const Duration(seconds: 60),
    Duration refreshQueueTimeout = const Duration(seconds: 10),
    Dio? httpClient,
  })  : _tokenProvider = tokenProvider,
        _refreshEndpointUrl = refreshEndpointUrl,
        _clientId = clientId,
        _customRefreshFn = customRefreshFn,
        _refreshThreshold = refreshThreshold,
        _refreshQueueTimeout = refreshQueueTimeout,
        _httpClient = httpClient {
    // Validate configuration
    if (refreshThreshold.inSeconds <= 0) {
      throw ArgumentError('refreshThreshold must be positive');
    }
    if ((refreshEndpointUrl == null || clientId == null) &&
        customRefreshFn == null) {
      throw ArgumentError(
        'Either refreshEndpointUrl+clientId OR customRefreshFn must be provided',
      );
    }
  }
  final TokenProvider _tokenProvider;
  final String? _refreshEndpointUrl;
  final String? _clientId;
  final Future<TokenRefreshResult> Function(String)? _customRefreshFn;
  final Duration _refreshThreshold;
  final Duration _refreshQueueTimeout;
  final Dio? _httpClient;

  // Refresh state management
  Completer<void>? _refreshCompleter;
  bool _isRefreshing = false;
  DateTime? _lastRefreshAttempt;
  int _backoffSeconds = 0;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip if Authorization header already exists (manual override)
    if (options.headers.containsKey('Authorization')) {
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
          options.headers['Authorization'] = 'Bearer $newToken';
        }
      } else {
        // Token is valid, inject it
        options.headers['Authorization'] = 'Bearer $accessToken';
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
    final isRetry =
        err.requestOptions.extra['_acdc_retry_after_refresh'] == true;
    if (isRetry) {
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
      requestOptions.headers['Authorization'] = 'Bearer $newToken';
      requestOptions.extra['_acdc_retry_after_refresh'] = true;

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
              requestOptions: RequestOptions(),
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
    _refreshCompleter!.future.catchError((_) {});

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
      // Check for exponential backoff
      if (_backoffSeconds > 0) {
        final timeSinceLastAttempt = _lastRefreshAttempt != null
            ? DateTime.now().difference(_lastRefreshAttempt!)
            : Duration.zero;

        if (timeSinceLastAttempt.inSeconds < _backoffSeconds) {
          await Future<void>.delayed(
            Duration(seconds: _backoffSeconds - timeSinceLastAttempt.inSeconds),
          );
        }
      }

      _lastRefreshAttempt = DateTime.now();

      // Get refresh token
      String? refreshToken;
      try {
        refreshToken = await _tokenProvider.getRefreshToken();
      } on Exception catch (e) {
        throw AcdcAuthException(
          requestOptions: RequestOptions(),
          message: 'Failed to retrieve refresh token: $e',
        );
      }

      if (refreshToken == null) {
        throw AcdcAuthException(
          requestOptions: RequestOptions(),
          message: 'No refresh token available',
        );
      }

      // Check if refresh token is expired
      try {
        final refreshExpiry = await _tokenProvider.getRefreshTokenExpiry();
        if (refreshExpiry != null &&
            refreshExpiry.isBefore(DateTime.now().toUtc())) {
          await _clearTokensSafely();
          throw AcdcAuthException(
            requestOptions: RequestOptions(),
            message: 'Refresh token expired. Please log in again.',
          );
        }
      } on Exception {
        // Ignore expiry check errors, proceed with refresh
      }

      // Perform refresh
      final result = _customRefreshFn != null
          ? await _customRefreshFn!(refreshToken)
          : await _performOAuthRefresh(refreshToken);

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
          requestOptions: RequestOptions(),
          message: 'Failed to store refreshed tokens: $e',
        );
      }

      // Reset backoff on success
      _backoffSeconds = 0;
    } on AcdcAuthException {
      // Auth errors - clear tokens
      await _clearTokensSafely();
      rethrow;
    } on AcdcNetworkException {
      // Network errors - don't clear tokens
      rethrow;
    } on AcdcServerException {
      // Server errors - apply exponential backoff
      _backoffSeconds =
          (_backoffSeconds == 0 ? 1 : _backoffSeconds * 2).clamp(0, 30);
      rethrow;
    }
  }

  /// Performs OAuth 2.1 token refresh.
  Future<TokenRefreshResult> _performOAuthRefresh(String refreshToken) async {
    // Use injected client or create a separate instance to avoid interceptor loops
    final dio = _httpClient ?? Dio();
    final refreshUrl = _refreshEndpointUrl!; // Promote to non-nullable

    try {
      final response = await dio.post<Map<String, dynamic>>(
        refreshUrl,
        data: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': _clientId,
        },
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          headers: {'Accept': 'application/json'},
        ),
      );

      final data = response.data!;

      // Extract tokens
      final accessToken = data['access_token'] as String?;
      if (accessToken == null) {
        throw AcdcAuthException(
          requestOptions: RequestOptions(path: refreshUrl),
          message: 'Refresh response missing access_token',
        );
      }

      final newRefreshToken = data['refresh_token'] as String?;
      final expiresIn = data['expires_in'] as int?;

      // Calculate expiry with clock skew handling
      DateTime? accessExpiry;
      if (expiresIn != null) {
        // Try to use server time from Date header
        final dateHeader = response.headers.value('date');
        if (dateHeader != null) {
          try {
            // Parse HTTP date format (RFC 1123)
            final serverTime = DateTime.parse(dateHeader);
            accessExpiry = serverTime.add(Duration(seconds: expiresIn));
          } on FormatException {
            // Fall back to local time if parsing fails
            accessExpiry =
                DateTime.now().toUtc().add(Duration(seconds: expiresIn));
          }
        } else {
          // No Date header - use local time
          accessExpiry =
              DateTime.now().toUtc().add(Duration(seconds: expiresIn));
        }
      }

      return TokenRefreshResult(
        accessToken: accessToken,
        refreshToken: newRefreshToken,
        accessExpiry: accessExpiry,
      );
    } on DioException catch (e) {
      // Handle OAuth error responses
      if (e.response?.statusCode == 400) {
        final data = e.response?.data;
        if (data is Map<String, dynamic>) {
          final error = data['error'] as String?;
          final errorDescription = data['error_description'] as String?;

          var message = _mapOAuthError(error);
          if (errorDescription != null) {
            message += ': $errorDescription';
          }

          throw AcdcAuthException.fromDioException(e, message: message);
        }
      }

      // Network or server errors
      rethrow;
    }
  }

  /// Maps OAuth error codes to user-friendly messages.
  String _mapOAuthError(String? error) {
    switch (error) {
      case 'invalid_grant':
        return 'Refresh token expired or invalid. Please log in again.';
      case 'invalid_client':
        return 'Client authentication failed. Check client configuration.';
      case 'unauthorized_client':
        return 'Client not authorized for token refresh.';
      case 'unsupported_grant_type':
        return 'Server does not support refresh token grant.';
      default:
        return 'Token refresh failed';
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
          requestOptions: RequestOptions(),
          message: 'Token refresh cancelled',
        ),
      );
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }
}
