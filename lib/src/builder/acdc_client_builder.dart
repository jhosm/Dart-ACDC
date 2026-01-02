import 'package:dart_acdc/src/auth/acdc_auth_manager.dart';
import 'package:dart_acdc/src/auth/token_provider.dart';
import 'package:dart_acdc/src/auth/token_refresh_result.dart';
import 'package:dart_acdc/src/cache/cache_config.dart';
import 'package:dart_acdc/src/interceptors/auth_interceptor.dart';
import 'package:dart_acdc/src/interceptors/cache_interceptor.dart';
import 'package:dart_acdc/src/interceptors/error_interceptor.dart';
import 'package:dart_acdc/src/interceptors/logging_interceptor.dart';
import 'package:dart_acdc/src/logging/acdc_logger.dart';
import 'package:dart_acdc/src/logging/log_level.dart';
import 'package:dio/dio.dart';

/// Immutable builder for creating pre-configured Dio HTTP clients.
///
/// Uses the builder pattern with immutability - each configuration method
/// returns a new builder instance, preserving the original.
///
/// Example:
/// ```dart
/// final dio = AcdcClientBuilder()
///   .withBaseUrl('https://api.example.com')
///   .withTimeout(Duration(seconds: 30))
///   .withLogLevel(LogLevel.debug)
///   .build();
/// ```
class AcdcClientBuilder {
  /// Creates a new builder with default configuration.
  const AcdcClientBuilder({
    String? baseUrl,
    Duration? timeout,
    TokenProvider? tokenProvider,
    String? tokenRefreshEndpointUrl,
    String? tokenRefreshClientId,
    Future<TokenRefreshResult> Function(String)? customTokenRefresh,
    String? tokenRevocationEndpoint,
    Duration? tokenRefreshThreshold,
    LogLevel? logLevel,
    AcdcLogger? logger,
    List<dynamic>? sensitiveFields,
    Duration? slowRequestThreshold,
    int? largePayloadThreshold,
    CacheConfig? cacheConfig,
    bool? cacheDisabled,
    List<Interceptor>? customInterceptors,
  })  : _baseUrl = baseUrl,
        _timeout = timeout,
        _tokenProvider = tokenProvider,
        _tokenRefreshEndpointUrl = tokenRefreshEndpointUrl,
        _tokenRefreshClientId = tokenRefreshClientId,
        _customTokenRefresh = customTokenRefresh,
        _tokenRevocationEndpoint = tokenRevocationEndpoint,
        _tokenRefreshThreshold = tokenRefreshThreshold,
        _logLevel = logLevel,
        _logger = logger,
        _sensitiveFields = sensitiveFields,
        _slowRequestThreshold = slowRequestThreshold,
        _largePayloadThreshold = largePayloadThreshold,
        _cacheConfig = cacheConfig,
        _cacheDisabled = cacheDisabled ?? false,
        _customInterceptors = customInterceptors;

  final String? _baseUrl;
  final Duration? _timeout;
  final TokenProvider? _tokenProvider;
  final String? _tokenRefreshEndpointUrl;
  final String? _tokenRefreshClientId;
  final Future<TokenRefreshResult> Function(String)? _customTokenRefresh;
  final String? _tokenRevocationEndpoint;
  final Duration? _tokenRefreshThreshold;
  final LogLevel? _logLevel;
  final AcdcLogger? _logger;
  final List<dynamic>? _sensitiveFields;
  final Duration? _slowRequestThreshold;
  final int? _largePayloadThreshold;
  final CacheConfig? _cacheConfig;
  final bool _cacheDisabled;
  final List<Interceptor>? _customInterceptors;

  /// Configures the base URL for all requests.
  ///
  /// Example: `https://api.example.com`
  ///
  /// Throws [ArgumentError] if the URL format is invalid.
  AcdcClientBuilder withBaseUrl(String url) {
    // Validation will be performed in build() method
    return AcdcClientBuilder(
      baseUrl: url,
      timeout: _timeout,
      tokenProvider: _tokenProvider,
      tokenRefreshEndpointUrl: _tokenRefreshEndpointUrl,
      tokenRefreshClientId: _tokenRefreshClientId,
      customTokenRefresh: _customTokenRefresh,
      tokenRevocationEndpoint: _tokenRevocationEndpoint,
      tokenRefreshThreshold: _tokenRefreshThreshold,
      logLevel: _logLevel,
      logger: _logger,
      sensitiveFields: _sensitiveFields,
      slowRequestThreshold: _slowRequestThreshold,
      largePayloadThreshold: _largePayloadThreshold,
      cacheConfig: _cacheConfig,
      cacheDisabled: _cacheDisabled,
      customInterceptors: _customInterceptors,
    );
  }

  /// Configures timeout for connection, send, and receive operations.
  ///
  /// Defaults to 5 seconds if not specified.
  ///
  /// Throws [ArgumentError] if timeout is not positive.
  AcdcClientBuilder withTimeout(Duration timeout) {
    if (timeout.inMicroseconds <= 0) {
      throw ArgumentError('Timeout duration must be positive');
    }

    return AcdcClientBuilder(
      baseUrl: _baseUrl,
      timeout: timeout,
      tokenProvider: _tokenProvider,
      tokenRefreshEndpointUrl: _tokenRefreshEndpointUrl,
      tokenRefreshClientId: _tokenRefreshClientId,
      customTokenRefresh: _customTokenRefresh,
      tokenRevocationEndpoint: _tokenRevocationEndpoint,
      tokenRefreshThreshold: _tokenRefreshThreshold,
      logLevel: _logLevel,
      logger: _logger,
      sensitiveFields: _sensitiveFields,
      slowRequestThreshold: _slowRequestThreshold,
      largePayloadThreshold: _largePayloadThreshold,
      cacheConfig: _cacheConfig,
      cacheDisabled: _cacheDisabled,
      customInterceptors: _customInterceptors,
    );
  }

  /// Configures the token provider for authentication.
  ///
  /// When configured, enables automatic token injection and refresh.
  AcdcClientBuilder withTokenProvider(TokenProvider provider) =>
      AcdcClientBuilder(
        baseUrl: _baseUrl,
        timeout: _timeout,
        tokenProvider: provider,
        tokenRefreshEndpointUrl: _tokenRefreshEndpointUrl,
        tokenRefreshClientId: _tokenRefreshClientId,
        customTokenRefresh: _customTokenRefresh,
        tokenRevocationEndpoint: _tokenRevocationEndpoint,
        tokenRefreshThreshold: _tokenRefreshThreshold,
        logLevel: _logLevel,
        logger: _logger,
        sensitiveFields: _sensitiveFields,
        slowRequestThreshold: _slowRequestThreshold,
        largePayloadThreshold: _largePayloadThreshold,
        cacheConfig: _cacheConfig,
        cacheDisabled: _cacheDisabled,
        customInterceptors: _customInterceptors,
      );

  /// Configures the OAuth 2.1 token refresh endpoint.
  ///
  /// Enables automatic token refresh using the standard OAuth flow.
  /// Requires both [url] and [clientId].
  ///
  /// Example:
  /// ```dart
  /// builder.withTokenRefreshEndpoint(
  ///   url: 'https://auth.example.com/oauth/token',
  ///   clientId: 'my-client-id',
  /// )
  /// ```
  AcdcClientBuilder withTokenRefreshEndpoint({
    required String url,
    required String clientId,
  }) =>
      AcdcClientBuilder(
        baseUrl: _baseUrl,
        timeout: _timeout,
        tokenProvider: _tokenProvider,
        tokenRefreshEndpointUrl: url,
        tokenRefreshClientId: clientId,
        customTokenRefresh: _customTokenRefresh,
        tokenRevocationEndpoint: _tokenRevocationEndpoint,
        tokenRefreshThreshold: _tokenRefreshThreshold,
        logLevel: _logLevel,
        logger: _logger,
        sensitiveFields: _sensitiveFields,
        slowRequestThreshold: _slowRequestThreshold,
        largePayloadThreshold: _largePayloadThreshold,
        cacheConfig: _cacheConfig,
        cacheDisabled: _cacheDisabled,
        customInterceptors: _customInterceptors,
      );

  /// Configures a custom token refresh function.
  ///
  /// Allows implementing custom token refresh logic instead of using
  /// the standard OAuth 2.1 flow.
  ///
  /// The function receives the refresh token and should return a
  /// [TokenRefreshResult] with the new tokens.
  ///
  /// Example:
  /// ```dart
  /// builder.withCustomTokenRefresh((refreshToken) async {
  ///   final response = await myCustomRefresh(refreshToken);
  ///   return TokenRefreshResult(
  ///     accessToken: response.accessToken,
  ///     refreshToken: response.refreshToken,
  ///   );
  /// })
  /// ```
  AcdcClientBuilder withCustomTokenRefresh(
    Future<TokenRefreshResult> Function(String) refreshFn,
  ) =>
      AcdcClientBuilder(
        baseUrl: _baseUrl,
        timeout: _timeout,
        tokenProvider: _tokenProvider,
        tokenRefreshEndpointUrl: _tokenRefreshEndpointUrl,
        tokenRefreshClientId: _tokenRefreshClientId,
        customTokenRefresh: refreshFn,
        tokenRevocationEndpoint: _tokenRevocationEndpoint,
        tokenRefreshThreshold: _tokenRefreshThreshold,
        logLevel: _logLevel,
        logger: _logger,
        sensitiveFields: _sensitiveFields,
        slowRequestThreshold: _slowRequestThreshold,
        largePayloadThreshold: _largePayloadThreshold,
        cacheConfig: _cacheConfig,
        cacheDisabled: _cacheDisabled,
        customInterceptors: _customInterceptors,
      );

  /// Configures the OAuth 2.1 token revocation endpoint.
  ///
  /// Used during logout to revoke tokens server-side.
  ///
  /// Example: `https://auth.example.com/oauth/revoke`
  AcdcClientBuilder withTokenRevocationEndpoint(String url) =>
      AcdcClientBuilder(
        baseUrl: _baseUrl,
        timeout: _timeout,
        tokenProvider: _tokenProvider,
        tokenRefreshEndpointUrl: _tokenRefreshEndpointUrl,
        tokenRefreshClientId: _tokenRefreshClientId,
        customTokenRefresh: _customTokenRefresh,
        tokenRevocationEndpoint: url,
        tokenRefreshThreshold: _tokenRefreshThreshold,
        logLevel: _logLevel,
        logger: _logger,
        sensitiveFields: _sensitiveFields,
        slowRequestThreshold: _slowRequestThreshold,
        largePayloadThreshold: _largePayloadThreshold,
        cacheConfig: _cacheConfig,
        cacheDisabled: _cacheDisabled,
        customInterceptors: _customInterceptors,
      );

  /// Configures the token refresh threshold.
  ///
  /// Tokens are proactively refreshed when their expiry is within this
  /// threshold. Defaults to 60 seconds.
  ///
  /// Example:
  /// ```dart
  /// builder.withTokenRefreshThreshold(Duration(seconds: 120))
  /// ```
  AcdcClientBuilder withTokenRefreshThreshold(Duration threshold) =>
      AcdcClientBuilder(
        baseUrl: _baseUrl,
        timeout: _timeout,
        tokenProvider: _tokenProvider,
        tokenRefreshEndpointUrl: _tokenRefreshEndpointUrl,
        tokenRefreshClientId: _tokenRefreshClientId,
        customTokenRefresh: _customTokenRefresh,
        tokenRevocationEndpoint: _tokenRevocationEndpoint,
        tokenRefreshThreshold: threshold,
        logLevel: _logLevel,
        logger: _logger,
        sensitiveFields: _sensitiveFields,
        slowRequestThreshold: _slowRequestThreshold,
        largePayloadThreshold: _largePayloadThreshold,
        cacheConfig: _cacheConfig,
        cacheDisabled: _cacheDisabled,
        customInterceptors: _customInterceptors,
      );

  /// Configures the logging verbosity level.
  ///
  /// Controls the amount of logging output. Use [LogLevel.none] to
  /// disable HTTP logging entirely.
  ///
  /// Defaults to [LogLevel.info] for production builds.
  AcdcClientBuilder withLogLevel(LogLevel level) => AcdcClientBuilder(
        baseUrl: _baseUrl,
        timeout: _timeout,
        tokenProvider: _tokenProvider,
        tokenRefreshEndpointUrl: _tokenRefreshEndpointUrl,
        tokenRefreshClientId: _tokenRefreshClientId,
        customTokenRefresh: _customTokenRefresh,
        tokenRevocationEndpoint: _tokenRevocationEndpoint,
        tokenRefreshThreshold: _tokenRefreshThreshold,
        logLevel: level,
        logger: _logger,
        sensitiveFields: _sensitiveFields,
        slowRequestThreshold: _slowRequestThreshold,
        largePayloadThreshold: _largePayloadThreshold,
        cacheConfig: _cacheConfig,
        cacheDisabled: _cacheDisabled,
        customInterceptors: _customInterceptors,
      );

  /// Configures a custom logger function.
  ///
  /// Allows integrating with custom logging systems (e.g., Firebase Crashlytics).
  ///
  /// Example:
  /// ```dart
  /// builder.withLogger((message, level, metadata) {
  ///   print('[$level] $message');
  ///   if (metadata != null) {
  ///     print('  Metadata: $metadata');
  ///   }
  /// })
  /// ```
  AcdcClientBuilder withLogger(AcdcLogger logger) => AcdcClientBuilder(
        baseUrl: _baseUrl,
        timeout: _timeout,
        tokenProvider: _tokenProvider,
        tokenRefreshEndpointUrl: _tokenRefreshEndpointUrl,
        tokenRefreshClientId: _tokenRefreshClientId,
        customTokenRefresh: _customTokenRefresh,
        tokenRevocationEndpoint: _tokenRevocationEndpoint,
        tokenRefreshThreshold: _tokenRefreshThreshold,
        logLevel: _logLevel,
        logger: logger,
        sensitiveFields: _sensitiveFields,
        slowRequestThreshold: _slowRequestThreshold,
        largePayloadThreshold: _largePayloadThreshold,
        cacheConfig: _cacheConfig,
        cacheDisabled: _cacheDisabled,
        customInterceptors: _customInterceptors,
      );

  /// Configures sensitive fields to redact from logs.
  ///
  /// Field names (for JSON) or query parameter names (for URLs) that
  /// contain sensitive data and should be redacted in logs.
  ///
  /// Example:
  /// ```dart
  /// builder.withSensitiveFields(['password', 'ssn', 'credit_card'])
  /// ```
  AcdcClientBuilder withSensitiveFields(List<dynamic> fields) =>
      AcdcClientBuilder(
        baseUrl: _baseUrl,
        timeout: _timeout,
        tokenProvider: _tokenProvider,
        tokenRefreshEndpointUrl: _tokenRefreshEndpointUrl,
        tokenRefreshClientId: _tokenRefreshClientId,
        customTokenRefresh: _customTokenRefresh,
        tokenRevocationEndpoint: _tokenRevocationEndpoint,
        tokenRefreshThreshold: _tokenRefreshThreshold,
        logLevel: _logLevel,
        logger: _logger,
        sensitiveFields: fields,
        slowRequestThreshold: _slowRequestThreshold,
        largePayloadThreshold: _largePayloadThreshold,
        cacheConfig: _cacheConfig,
        cacheDisabled: _cacheDisabled,
        customInterceptors: _customInterceptors,
      );

  /// Configures the threshold for slow request warnings.
  ///
  /// Requests taking longer than this duration trigger warning logs.
  /// Defaults to 3 seconds.
  ///
  /// Example:
  /// ```dart
  /// builder.withSlowRequestThreshold(Duration(seconds: 5))
  /// ```
  AcdcClientBuilder withSlowRequestThreshold(Duration threshold) =>
      AcdcClientBuilder(
        baseUrl: _baseUrl,
        timeout: _timeout,
        tokenProvider: _tokenProvider,
        tokenRefreshEndpointUrl: _tokenRefreshEndpointUrl,
        tokenRefreshClientId: _tokenRefreshClientId,
        customTokenRefresh: _customTokenRefresh,
        tokenRevocationEndpoint: _tokenRevocationEndpoint,
        tokenRefreshThreshold: _tokenRefreshThreshold,
        logLevel: _logLevel,
        logger: _logger,
        sensitiveFields: _sensitiveFields,
        slowRequestThreshold: threshold,
        largePayloadThreshold: _largePayloadThreshold,
        cacheConfig: _cacheConfig,
        cacheDisabled: _cacheDisabled,
        customInterceptors: _customInterceptors,
      );

  /// Configures the threshold for large payload warnings.
  ///
  /// Request/response bodies larger than this size (in bytes) trigger
  /// warning logs. Defaults to 100 KB.
  ///
  /// Example:
  /// ```dart
  /// builder.withLargePayloadThreshold(1024 * 1024) // 1 MB
  /// ```
  AcdcClientBuilder withLargePayloadThreshold(int bytes) => AcdcClientBuilder(
        baseUrl: _baseUrl,
        timeout: _timeout,
        tokenProvider: _tokenProvider,
        tokenRefreshEndpointUrl: _tokenRefreshEndpointUrl,
        tokenRefreshClientId: _tokenRefreshClientId,
        customTokenRefresh: _customTokenRefresh,
        tokenRevocationEndpoint: _tokenRevocationEndpoint,
        tokenRefreshThreshold: _tokenRefreshThreshold,
        logLevel: _logLevel,
        logger: _logger,
        sensitiveFields: _sensitiveFields,
        slowRequestThreshold: _slowRequestThreshold,
        largePayloadThreshold: bytes,
        cacheConfig: _cacheConfig,
        cacheDisabled: _cacheDisabled,
        customInterceptors: _customInterceptors,
      );

  /// Configures HTTP caching with custom settings.
  ///
  /// Overrides default cache configuration. Caching is enabled by default
  /// with sensible settings.
  ///
  /// Example:
  /// ```dart
  /// builder.withCache(CacheConfig(
  ///   ttl: Duration(hours: 2),
  ///   maxSize: 20 * 1024 * 1024, // 20 MB
  ///   encrypted: true,
  /// ))
  /// ```
  AcdcClientBuilder withCache(CacheConfig config) => AcdcClientBuilder(
        baseUrl: _baseUrl,
        timeout: _timeout,
        tokenProvider: _tokenProvider,
        tokenRefreshEndpointUrl: _tokenRefreshEndpointUrl,
        tokenRefreshClientId: _tokenRefreshClientId,
        customTokenRefresh: _customTokenRefresh,
        tokenRevocationEndpoint: _tokenRevocationEndpoint,
        tokenRefreshThreshold: _tokenRefreshThreshold,
        logLevel: _logLevel,
        logger: _logger,
        sensitiveFields: _sensitiveFields,
        slowRequestThreshold: _slowRequestThreshold,
        largePayloadThreshold: _largePayloadThreshold,
        cacheConfig: config,
        cacheDisabled: false,
        customInterceptors: _customInterceptors,
      );

  /// Disables HTTP caching.
  ///
  /// All requests bypass the cache and hit the network.
  ///
  /// Example:
  /// ```dart
  /// builder.disableCache()
  /// ```
  AcdcClientBuilder disableCache() => AcdcClientBuilder(
        baseUrl: _baseUrl,
        timeout: _timeout,
        tokenProvider: _tokenProvider,
        tokenRefreshEndpointUrl: _tokenRefreshEndpointUrl,
        tokenRefreshClientId: _tokenRefreshClientId,
        customTokenRefresh: _customTokenRefresh,
        tokenRevocationEndpoint: _tokenRevocationEndpoint,
        tokenRefreshThreshold: _tokenRefreshThreshold,
        logLevel: _logLevel,
        logger: _logger,
        sensitiveFields: _sensitiveFields,
        slowRequestThreshold: _slowRequestThreshold,
        largePayloadThreshold: _largePayloadThreshold,
        cacheDisabled: true,
        customInterceptors: _customInterceptors,
      );

  /// Adds a custom interceptor to the interceptor chain.
  ///
  /// Custom interceptors are added after all built-in interceptors
  /// (auth, cache, error, logging).
  ///
  /// Multiple custom interceptors can be added by calling this method
  /// multiple times. They will execute in the order they were added.
  ///
  /// Example:
  /// ```dart
  /// builder
  ///   .withInterceptor(MyCustomInterceptor())
  ///   .withInterceptor(AnotherInterceptor())
  /// ```
  AcdcClientBuilder withInterceptor(Interceptor interceptor) {
    final updatedInterceptors = [
      ...?_customInterceptors,
      interceptor,
    ];

    return AcdcClientBuilder(
      baseUrl: _baseUrl,
      timeout: _timeout,
      tokenProvider: _tokenProvider,
      tokenRefreshEndpointUrl: _tokenRefreshEndpointUrl,
      tokenRefreshClientId: _tokenRefreshClientId,
      customTokenRefresh: _customTokenRefresh,
      tokenRevocationEndpoint: _tokenRevocationEndpoint,
      tokenRefreshThreshold: _tokenRefreshThreshold,
      logLevel: _logLevel,
      logger: _logger,
      sensitiveFields: _sensitiveFields,
      slowRequestThreshold: _slowRequestThreshold,
      largePayloadThreshold: _largePayloadThreshold,
      cacheConfig: _cacheConfig,
      cacheDisabled: _cacheDisabled,
      customInterceptors: updatedInterceptors,
    );
  }

  /// Builds and returns a configured Dio instance.
  ///
  /// Creates a new Dio instance each time, allowing builder reuse.
  /// The builder can be called multiple times to create independent
  /// Dio instances with the same configuration.
  ///
  /// Throws [ArgumentError] if validation fails (e.g., invalid URL format).
  ///
  /// Example:
  /// ```dart
  /// final builder = AcdcClientBuilder()
  ///   .withBaseUrl('https://api.example.com');
  ///
  /// final dio1 = builder.build();  // First instance
  /// final dio2 = builder.build();  // Second instance, independent
  /// ```
  Dio build() {
    // Validate base URL format if provided
    if (_baseUrl != null && _baseUrl!.isNotEmpty) {
      final uri = Uri.tryParse(_baseUrl!);
      if (uri == null ||
          (!uri.hasScheme ||
              (!uri.isScheme('http') && !uri.isScheme('https')))) {
        throw ArgumentError(
          'Invalid base URL format: "$_baseUrl". '
          'Expected format: https://api.example.com',
        );
      }
    }

    // Create new Dio instance
    final dio = Dio();

    // Configure base URL if provided
    if (_baseUrl != null) {
      dio.options.baseUrl = _baseUrl!;
    }

    // Set default or custom timeouts (5s default for connect, send, receive)
    final timeout = _timeout ?? const Duration(seconds: 5);
    dio.options.connectTimeout = timeout;
    dio.options.sendTimeout = timeout;
    dio.options.receiveTimeout = timeout;

    // Set up authentication if configured
    AuthInterceptor? authInterceptor;
    if (_tokenProvider != null) {
      // Create auth interceptor
      authInterceptor = AuthInterceptor(
        tokenProvider: _tokenProvider!,
        refreshEndpointUrl: _tokenRefreshEndpointUrl,
        clientId: _tokenRefreshClientId,
        customRefreshFn: _customTokenRefresh,
        refreshThreshold: _tokenRefreshThreshold ?? const Duration(seconds: 60),
      );

      // Create auth manager and store in Dio options
      final authManager = AcdcAuthManager(
        tokenProvider: _tokenProvider!,
        authInterceptor: authInterceptor,
        revocationEndpointUrl: _tokenRevocationEndpoint,
        clientId: _tokenRefreshClientId,
      );

      // Store auth manager in Dio options for extension access
      dio.options.extra['_acdc_auth_manager'] = authManager;
    }

    // Set up interceptor chain in correct order
    // Request phase: [Logging →] Auth [→ Cache]
    // Response phase: [Cache →] Auth → Error [→ Logging]
    // Custom interceptors are added at the end

    // Add auth interceptor if configured
    if (authInterceptor != null) {
      dio.interceptors.add(authInterceptor);
    }

    // Add cache interceptor if caching is enabled
    if (!_cacheDisabled) {
      final cacheConfig = _cacheConfig ?? const CacheConfig();
      dio.interceptors.add(AcdcCacheInterceptor(config: cacheConfig));
    }

    // Add error interceptor (always present)
    dio.interceptors.add(const ErrorInterceptor());

    // Add logging interceptor (before auth in request, after error in response)
    // Note: Due to Dio's FIFO interceptor handling, we add it first so it's first in request chain
    // and last in response chain (wrapping everything).

    // Default to info level if not specified
    final logLevel = _logLevel ?? LogLevel.info;

    // Only add if logging is enabled (not none)
    if (logLevel != LogLevel.none) {
      dio.interceptors.add(LoggingInterceptor(
        level: logLevel,
        logger: _logger,
      ),);
    }

    // Add custom interceptors at the end
    if (_customInterceptors != null) {
      dio.interceptors.addAll(_customInterceptors!);
    }

    return dio;
  }
}
