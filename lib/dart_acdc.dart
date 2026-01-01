/// ACDC - Advanced Client for Dio Communication
///
/// A production-ready HTTP client library built on top of Dio, providing:
///
/// **Authentication**:
/// - Automatic token injection and refresh (OAuth 2.1 compliant)
/// - Proactive refresh before token expiry
/// - Reactive refresh on 401 responses
/// - Concurrent request queuing during refresh
/// - Token revocation on logout
/// - Support for custom token refresh logic
///
/// **Caching**:
/// - HTTP-compliant caching with Cache-Control support
/// - User-based cache isolation
/// - Optional encrypted cache storage
/// - In-memory cache layer
/// - Offline support with stale-while-revalidate
///
/// **Error Handling**:
/// - Structured exception hierarchy
/// - Developer-friendly error messages
/// - Automatic retry with exponential backoff
/// - Network error classification
///
/// **Logging**:
/// - Environment-aware logging (debug vs release)
/// - Sensitive data redaction
/// - Custom logger integration
/// - Request duration tracking
///
/// ## Quick Start
///
/// **Zero-config usage** (minimal setup):
/// ```dart
/// import 'package:dart_acdc/dart_acdc.dart';
///
/// final dio = AcdcClientBuilder()
///   .withBaseUrl('https://api.example.com')
///   .build();
///
/// final response = await dio.get('/users');
/// ```
///
/// **With authentication**:
/// ```dart
/// // Implement TokenProvider to store/retrieve tokens
/// class MyTokenProvider implements TokenProvider {
///   @override
///   Future<String?> getAccessToken() async => // ... load from secure storage
///
///   @override
///   Future<String?> getRefreshToken() async => // ... load from secure storage
///
///   @override
///   Future<void> setTokens({
///     required String accessToken,
///     String? refreshToken,
///     DateTime? accessExpiry,
///     DateTime? refreshExpiry,
///   }) async {
///     // ... save to secure storage
///   }
///
///   @override
///   Future<void> clearTokens() async {
///     // ... clear from secure storage
///   }
///
///   @override
///   Future<DateTime?> getAccessTokenExpiry() async => // ... optional
///
///   @override
///   Future<DateTime?> getRefreshTokenExpiry() async => // ... optional
/// }
///
/// final dio = AcdcClientBuilder()
///   .withBaseUrl('https://api.example.com')
///   .withTokenProvider(MyTokenProvider())
///   .withTokenRefreshEndpoint(
///     url: 'https://auth.example.com/oauth/token',
///     clientId: 'my-client-id',
///   )
///   .withTokenRevocationEndpoint('https://auth.example.com/oauth/revoke')
///   .build();
///
/// // Make authenticated requests
/// final response = await dio.get('/protected-resource');
///
/// // Logout
/// await dio.auth.logout();
/// ```
///
/// **With custom configuration**:
/// ```dart
/// final dio = AcdcClientBuilder()
///   .withBaseUrl('https://api.example.com')
///   .withTimeout(Duration(seconds: 30))
///   .withLogLevel(LogLevel.debug)
///   .withCache(CacheConfig(
///     ttl: Duration(hours: 2),
///     encrypted: true,
///   ))
///   .build();
/// ```
///
/// ## Exception Handling
///
/// All HTTP and network errors are converted to typed exceptions:
///
/// ```dart
/// try {
///   final response = await dio.get('/users');
/// } on AcdcAuthException catch (e) {
///   // Handle 401/403 errors
///   print('Authentication error: ${e.message}');
/// } on AcdcServerException catch (e) {
///   // Handle 5xx errors
///   print('Server error: ${e.message}');
/// } on AcdcNetworkException catch (e) {
///   // Handle network failures
///   print('Network error: ${e.errorType}');
/// } on AcdcClientException catch (e) {
///   // Handle 4xx errors (other than 401/403)
///   print('Client error: ${e.message}');
/// }
/// ```
///
/// ## Custom Logger
///
/// Integrate with your logging system:
///
/// ```dart
/// final dio = AcdcClientBuilder()
///   .withLogger((message, level, metadata) {
///     // Forward to your logging system
///     myLogger.log(level, message, metadata);
///   })
///   .build();
/// ```
///
/// ## Advanced Features
///
/// **Force token refresh**:
/// ```dart
/// await dio.auth.refreshNow();
/// ```
///
/// **Clear cache**:
/// ```dart
/// await dio.auth.clearCache();
/// ```
///
/// **Custom token refresh**:
/// ```dart
/// final dio = AcdcClientBuilder()
///   .withTokenProvider(myTokenProvider)
///   .withCustomTokenRefresh((refreshToken) async {
///     // Your custom refresh logic
///     final response = await myCustomRefreshCall(refreshToken);
///     return TokenRefreshResult(
///       accessToken: response.accessToken,
///       refreshToken: response.newRefreshToken,
///     );
///   })
///   .build();
/// ```
///
/// ## Security Best Practices
///
/// 1. **Token Storage**: Use platform secure storage (iOS Keychain, Android Keystore)
/// 2. **OAuth 2.1**: This library follows OAuth 2.1 for public clients (no client_secret)
/// 3. **Cache Encryption**: Enable for sensitive data with `CacheConfig(encrypted: true)`
/// 4. **HTTPS Only**: Always use HTTPS URLs in production
///
/// ## Supported Dart/Flutter Versions
///
/// - Dart SDK: >=3.0.0 <4.0.0
/// - Flutter: >=3.10.0
///
/// ## License
///
/// See LICENSE file for details.
library dart_acdc;

// ============================================================================
// Builder
// ============================================================================

/// Manager for authentication operations (logout, refresh, clear cache).
///
/// Access via `dio.auth` extension after configuring authentication.
export 'src/auth/acdc_auth_manager.dart' show AcdcAuthManager, AcdcAuth;
/// Interface for storing and retrieving authentication tokens.
///
/// Implement this to integrate with your secure storage solution
/// (iOS Keychain, Android Keystore, flutter_secure_storage, etc.).
export 'src/auth/token_provider.dart' show TokenProvider;
/// Result of a token refresh operation.
///
/// Contains new access token and optionally a new refresh token
/// (when token rotation is enabled).
export 'src/auth/token_refresh_result.dart' show TokenRefreshResult;
/// HTTP client builder with fluent API.
///
/// Use this to configure and create Dio instances with authentication,
/// caching, logging, and error handling built-in.
export 'src/builder/acdc_client_builder.dart' show AcdcClientBuilder;
/// Configuration for HTTP response caching.
///
/// Controls cache TTL, size limits, encryption, and offline behavior.
export 'src/cache/cache_config.dart' show CacheConfig;
/// Authentication errors (401, 403, token refresh failures).
export 'src/exceptions/acdc_auth_exception.dart' show AcdcAuthException;
/// Cache operation errors.
export 'src/exceptions/acdc_cache_exception.dart'
    show AcdcCacheException, CacheOperation;
/// Client errors (4xx status codes, except 401/403).
export 'src/exceptions/acdc_client_exception.dart' show AcdcClientException;
/// Base exception class for all ACDC errors.
///
/// All exceptions extend DioException for compatibility with Dio error handling.
export 'src/exceptions/acdc_exception.dart' show AcdcException;
/// Network connectivity errors (timeouts, connection failures, DNS errors).
export 'src/exceptions/acdc_network_exception.dart'
    show AcdcNetworkException, NetworkErrorType;
/// Server errors (5xx status codes).
export 'src/exceptions/acdc_server_exception.dart' show AcdcServerException;
/// Custom logger function type.
///
/// Implement this to integrate with your logging system
/// (Firebase Crashlytics, Sentry, etc.).
///
/// Example:
/// ```dart
/// void myLogger(String message, LogLevel level, Map<String, dynamic>? metadata) {
///   print('[$level] $message');
///   if (metadata != null) {
///     print('  Metadata: $metadata');
///   }
/// }
/// ```
export 'src/logging/acdc_logger.dart' show AcdcLogger;
/// Log level for controlling logging verbosity.
///
/// Use LogLevel.none to disable HTTP logging entirely.
export 'src/logging/log_level.dart' show LogLevel;
