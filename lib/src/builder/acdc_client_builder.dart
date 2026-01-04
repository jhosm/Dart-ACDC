import 'package:dart_acdc/src/auth/acdc_auth_manager.dart';
import 'package:dart_acdc/src/auth/secure_token_provider.dart';
import 'package:dart_acdc/src/auth/token_provider.dart';
import 'package:dart_acdc/src/auth/token_refresh_result.dart';
import 'package:dart_acdc/src/cache/acdc_cache_manager.dart';
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
    bool? authDisabled,
    List<Interceptor>? customInterceptors,
    String? initialAccessToken,
    String? initialRefreshToken,
    DateTime? initialAccessExpiry,
    DateTime? initialRefreshExpiry,
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
        _authDisabled = authDisabled ?? false,
        _customInterceptors = customInterceptors,
        _initialAccessToken = initialAccessToken,
        _initialRefreshToken = initialRefreshToken,
        _initialAccessExpiry = initialAccessExpiry,
        _initialRefreshExpiry = initialRefreshExpiry;

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
  final bool _authDisabled;
  final List<Interceptor>? _customInterceptors;
  final String? _initialAccessToken;
  final String? _initialRefreshToken;
  final DateTime? _initialAccessExpiry;
  final DateTime? _initialRefreshExpiry;

  /// Configures the base URL for all requests.
  ///
  /// Example: `https://api.example.com`
  ///
  /// Throws [ArgumentError] if the URL format is invalid.
  AcdcClientBuilder withBaseUrl(String url) => _copyWith(baseUrl: url);

  /// Configures timeout for connection, send, and receive operations.
  ///
  /// Defaults to 5 seconds if not specified.
  ///
  /// Throws [ArgumentError] if timeout is not positive.
  AcdcClientBuilder withTimeout(Duration timeout) {
    if (timeout.inMicroseconds <= 0) {
      throw ArgumentError('Timeout duration must be positive');
    }

    return _copyWith(timeout: timeout);
  }

  /// Configures the token provider for authentication.
  ///
  /// When configured, enables automatic token injection and refresh.
  AcdcClientBuilder withTokenProvider(TokenProvider provider) =>
      _copyWith(tokenProvider: provider);

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
      _copyWith(
        tokenRefreshEndpointUrl: url,
        tokenRefreshClientId: clientId,
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
      _copyWith(customTokenRefresh: refreshFn);

  /// Configures the OAuth 2.1 token revocation endpoint.
  ///
  /// Used during logout to revoke tokens server-side.
  ///
  /// Example: `https://auth.example.com/oauth/revoke`
  AcdcClientBuilder withTokenRevocationEndpoint(String url) =>
      _copyWith(tokenRevocationEndpoint: url);

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
      _copyWith(tokenRefreshThreshold: threshold);

  /// Configures the logging verbosity level.
  ///
  /// Controls the amount of logging output. Use [LogLevel.none] to
  /// disable HTTP logging entirely.
  ///
  /// Defaults to [LogLevel.info] for production builds.
  AcdcClientBuilder withLogLevel(LogLevel level) => _copyWith(logLevel: level);

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
  AcdcClientBuilder withLogger(AcdcLogger logger) => _copyWith(logger: logger);

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
      _copyWith(sensitiveFields: fields);

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
      _copyWith(slowRequestThreshold: threshold);

  /// Configures the threshold for large payload warnings.
  ///
  /// Request/response bodies larger than this size (in bytes) trigger
  /// warning logs. Defaults to 100 KB.
  ///
  /// Example:
  /// ```dart
  /// builder.withLargePayloadThreshold(1024 * 1024) // 1 MB
  /// ```
  AcdcClientBuilder withLargePayloadThreshold(int bytes) =>
      _copyWith(largePayloadThreshold: bytes);

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
  /// ))
  /// ```
  AcdcClientBuilder withCache(CacheConfig config) => _copyWith(
        cacheConfig: config,
        cacheDisabled: false,
      );

  /// Disables HTTP caching.
  ///
  /// All requests bypass the cache and hit the network.
  ///
  /// Example:
  /// ```dart
  /// builder.disableCache()
  /// ```
  AcdcClientBuilder disableCache() => _copyWith(cacheDisabled: true);

  /// Disables authentication.
  ///
  /// The client will not inject tokens, handle 401s, or perform refreshes.
  /// However, accessing `dio.auth` will still work for cache operations.
  ///
  /// Example:
  /// ```dart
  /// builder.disableAuth()
  /// ```
  AcdcClientBuilder disableAuth() => _copyWith(authDisabled: true);

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

    return _copyWith(customInterceptors: updatedInterceptors);
  }

  /// Configures initial authentication tokens.
  ///
  /// Using this allows initializing the client with known tokens (e.g. after login),
  /// which will be written to the configured TokenProvider before the client is built.
  AcdcClientBuilder withInitialTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? accessExpiry,
    DateTime? refreshExpiry,
  }) {
    return _copyWith(
      initialAccessToken: accessToken,
      initialRefreshToken: refreshToken,
      initialAccessExpiry: accessExpiry,
      initialRefreshExpiry: refreshExpiry,
    );
  }

  AcdcClientBuilder _copyWith({
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
    bool? authDisabled,
    List<Interceptor>? customInterceptors,
    String? initialAccessToken,
    String? initialRefreshToken,
    DateTime? initialAccessExpiry,
    DateTime? initialRefreshExpiry,
  }) {
    return AcdcClientBuilder(
      baseUrl: baseUrl ?? _baseUrl,
      timeout: timeout ?? _timeout,
      tokenProvider: tokenProvider ?? _tokenProvider,
      tokenRefreshEndpointUrl:
          tokenRefreshEndpointUrl ?? _tokenRefreshEndpointUrl,
      tokenRefreshClientId: tokenRefreshClientId ?? _tokenRefreshClientId,
      customTokenRefresh: customTokenRefresh ?? _customTokenRefresh,
      tokenRevocationEndpoint:
          tokenRevocationEndpoint ?? _tokenRevocationEndpoint,
      tokenRefreshThreshold: tokenRefreshThreshold ?? _tokenRefreshThreshold,
      logLevel: logLevel ?? _logLevel,
      logger: logger ?? _logger,
      sensitiveFields: sensitiveFields ?? _sensitiveFields,
      slowRequestThreshold: slowRequestThreshold ?? _slowRequestThreshold,
      largePayloadThreshold: largePayloadThreshold ?? _largePayloadThreshold,
      cacheConfig: cacheConfig ?? _cacheConfig,
      cacheDisabled: cacheDisabled ?? _cacheDisabled,
      authDisabled: authDisabled ?? _authDisabled,
      customInterceptors: customInterceptors ?? _customInterceptors,
      initialAccessToken: initialAccessToken ?? _initialAccessToken,
      initialRefreshToken: initialRefreshToken ?? _initialRefreshToken,
      initialAccessExpiry: initialAccessExpiry ?? _initialAccessExpiry,
      initialRefreshExpiry: initialRefreshExpiry ?? _initialRefreshExpiry,
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
  /// final dio1 = await builder.build();  // First instance
  /// final dio2 = await builder.build();  // Second instance, independent
  /// ```
  Future<Dio> build() async {
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

    // Set up cache interceptor if caching is enabled
    AcdcCacheInterceptor? cacheInterceptor;
    if (!_cacheDisabled) {
      final cacheConfig = _cacheConfig ?? const CacheConfig();
      cacheInterceptor = AcdcCacheInterceptor(config: cacheConfig);
    }

    // Set up authentication (defaults to SecureTokenProvider)
    final tokenProvider = _tokenProvider ?? const SecureTokenProvider();

    // Handle initial tokens if provided (only if auth is enabled)
    if (!_authDisabled && _initialAccessToken != null) {
      await tokenProvider.setTokens(
        accessToken: _initialAccessToken!,
        refreshToken: _initialRefreshToken,
        accessExpiry: _initialAccessExpiry,
        refreshExpiry: _initialRefreshExpiry,
      );
    }

    // Create auth interceptor if auth is enabled
    AuthInterceptor? authInterceptor;
    if (!_authDisabled) {
      authInterceptor = AuthInterceptor(
        tokenProvider: tokenProvider,
        refreshEndpointUrl: _tokenRefreshEndpointUrl,
        clientId: _tokenRefreshClientId,
        customRefreshFn: _customTokenRefresh,
        refreshThreshold: _tokenRefreshThreshold ?? const Duration(seconds: 60),
      );
    }

    // Create cache manager
    final cacheManager = AcdcCacheManager(
      cacheInterceptor: cacheInterceptor,
    );

    // Store cache manager in Dio options for extension access
    dio.options.extra['_acdc_cache_manager'] = cacheManager;

    // Create auth manager and store in Dio options
    // Pass nulls if auth is disabled
    final authManager = AcdcAuthManager(
      tokenProvider: _authDisabled ? null : tokenProvider,
      authInterceptor: authInterceptor,
      revocationEndpointUrl: _tokenRevocationEndpoint,
      clientId: _tokenRefreshClientId,
      cacheManager: cacheManager,
    );

    // Store auth manager in Dio options for extension access
    dio.options.extra['_acdc_auth_manager'] = authManager;

    // Set up interceptor chain in correct order
    // Request phase: Logging → Error → Auth → Cache
    // Response phase: Cache → Auth → Error → Logging
    // Custom interceptors are added at the end

    // 1. Add logging interceptor (Outer-most)
    final logLevel = _logLevel ?? LogLevel.info;
    if (logLevel != LogLevel.none) {
      dio.interceptors.add(
        LoggingInterceptor(
          level: logLevel,
          logger: _logger,
        ),
      );
    }

    // 2. Add error interceptor
    dio.interceptors.add(const ErrorInterceptor());

    // 3. Add auth interceptor if enabled
    if (authInterceptor != null) {
      dio.interceptors.add(authInterceptor);
    }

    // 4. Add cache interceptor if caching is enabled
    if (cacheInterceptor != null) {
      dio.interceptors.add(cacheInterceptor);
    }

    // 5. Add custom interceptors at the end
    if (_customInterceptors != null) {
      dio.interceptors.addAll(_customInterceptors!);
    }

    return dio;
  }
}
