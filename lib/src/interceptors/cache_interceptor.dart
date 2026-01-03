import 'package:dart_acdc/src/cache/cache_config.dart';
import 'package:dart_acdc/src/cache/encrypted_cache_store.dart';
import 'package:dart_acdc/src/cache/jwt_utils.dart';
import 'package:dart_acdc/src/cache/two_tier_cache_store.dart';
import 'package:dart_acdc/src/exceptions/acdc_network_exception.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

/// Wrapper for dio_cache_interceptor that integrates with [CacheConfig].
///
/// Provides HTTP response caching with:
/// - Configurable TTL and size limits
/// - In-memory cache layer
/// - Cache-Control, ETag, and Last-Modified header respect
/// - 304 Not Modified handling
/// - Method-based caching (GET/HEAD only)
/// - Automatic cache invalidation on mutations
/// - Stale-while-revalidate support
/// - User isolation for authenticated requests (REQUIRED)
///
/// IMPORTANT: Caching behavior:
/// - Unauthenticated requests: Cached normally (shared cache)
/// - Authenticated requests with identifiable user: Cached with user isolation
/// - Authenticated requests without identifiable user: NOT cached (security)
class AcdcCacheInterceptor extends Interceptor {
  /// Creates a cache interceptor from configuration.
  ///
  /// Builds appropriate cache stores based on [config] settings:
  /// - Uses in-memory cache with configured size limits
  /// - Optionally encrypts cache with platform secure storage
  /// - Supports two-tier caching (memory + persistent)
  /// - Configures cache policies based on config flags
  /// - Only caches GET and HEAD requests
  /// - Invalidates cache on POST/PUT/DELETE/PATCH requests
  /// - Requires user ID extraction for caching (user isolation)
  ///
  /// Throws [StateError] if encryption is required but unavailable.
  AcdcCacheInterceptor({
    required CacheConfig config,
  })  : _config = config,
        _cacheOptions = CacheOptions(
          // Build appropriate cache store based on config
          store: _buildCacheStore(config),

          // Cache policy based on config - respects HTTP directives
          policy: config.staleWhileRevalidate
              ? CachePolicy.refreshForceCache
              : CachePolicy.request,

          // TTL configuration
          maxStale: config.staleIfError ? const Duration(days: 7) : null,

          // Hit cache on network errors if configured
          hitCacheOnErrorExcept: config.staleIfError ? [] : [401, 403],

          // Custom key builder that includes user ID for isolation
          keyBuilder: (request) => buildCacheKeyWithUserIsolation(
            request,
            customKeyBuilder: config.keyBuilder,
          ),
        ),
        _dioCacheInterceptor = DioCacheInterceptor(
          options: CacheOptions(
            store: _buildCacheStore(config),
            policy: config.staleWhileRevalidate
                ? CachePolicy.refreshForceCache
                : CachePolicy.request,
            maxStale: config.staleIfError ? const Duration(days: 7) : null,
            hitCacheOnErrorExcept: config.staleIfError ? [] : [401, 403],
            keyBuilder: (request) => buildCacheKeyWithUserIsolation(
              request,
              customKeyBuilder: config.keyBuilder,
            ),
          ),
        );

  final CacheConfig _config;
  final CacheOptions _cacheOptions;
  final DioCacheInterceptor _dioCacheInterceptor;

  /// Builds the appropriate cache store based on configuration.
  ///
  /// Returns:
  /// - TwoTierCacheStore: If both inMemory and encryption are enabled
  /// - EncryptedCacheStore: If only encryption is enabled
  /// - MemCacheStore: If only inMemory is enabled (default)
  ///
  /// Throws [StateError] if encryption is required but unavailable.
  static CacheStore _buildCacheStore(CacheConfig config) {
    // Build persistent store (always encrypted)
    final persistentStore = EncryptedCacheStore(
      maxSize: config.maxSize,
      version: config.version,
      onError: config.onError,
    );

    // Build two-tier cache if inMemory is enabled
    if (config.inMemory) {
      final memoryStore = MemCacheStore(
        maxSize: config.inMemoryMaxSize,
      );

      // Two-tier: memory + encrypted persistent
      return TwoTierCacheStore(
        memoryStore: memoryStore,
        persistentStore: persistentStore,
      );
    }

    // Persistent-only cache (always encrypted)
    return persistentStore;
  }

  /// Builds a cache key with user isolation.
  ///
  /// Returns:
  /// - Unauthenticated: Standard key `{method}:{url}` (shared cache)
  /// - Authenticated with user ID: `{method}:{url}:{userId}` (user-isolated)
  /// - Authenticated without user ID: Empty string (no caching)
  ///
  /// The user ID is stored in `options.extra['_acdc_user_id']` by onRequest.
  /// The auth flag is stored in `options.extra['_acdc_has_auth']`.
  ///
  /// This method is public to enable testing but should not be called directly
  /// by library users.
  static String buildCacheKeyWithUserIsolation(
    RequestOptions options, {
    String Function(RequestOptions)? customKeyBuilder,
  }) {
    final userId = options.extra['_acdc_user_id'] as String?;
    final hasAuth = options.extra['_acdc_has_auth'] as bool? ?? false;

    // Build base cache key
    final baseKey = customKeyBuilder?.call(options) ??
        CacheOptions.defaultCacheKeyBuilder(options);

    if (!hasAuth) {
      // Unauthenticated request - use standard shared cache
      return baseKey;
    }

    if (userId == null || userId.isEmpty) {
      // Authenticated but no user ID - disable caching for security
      // dio_cache_interceptor treats empty keys as non-cacheable
      return '';
    }

    // Authenticated with user ID - use user-isolated cache
    return '$baseKey:$userId';
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Extract user ID from Authorization header for cache isolation
    await _extractAndStoreUserId(options);

    // Delegate to dio_cache_interceptor
    _dioCacheInterceptor.onRequest(options, handler);
  }

  /// Extracts user ID from Authorization header and stores it in request extras.
  ///
  /// Sets two flags in options.extra:
  /// - `_acdc_has_auth`: true if Authorization header is present
  /// - `_acdc_user_id`: extracted user ID (if available)
  ///
  /// This enables proper cache key generation:
  /// - No auth → shared cache
  /// - Auth + user ID → user-isolated cache
  /// - Auth but no user ID → no caching (security)
  Future<void> _extractAndStoreUserId(RequestOptions options) async {
    // Get Authorization header
    final authHeader = options.headers['Authorization']?.toString();
    if (authHeader == null || authHeader.isEmpty) {
      // No auth header - will use shared cache
      options.extra['_acdc_has_auth'] = false;
      return;
    }

    // Mark as authenticated
    options.extra['_acdc_has_auth'] = true;

    // Extract token from "Bearer {token}" format
    final token = _extractToken(authHeader);
    if (token == null || token.isEmpty) {
      // Has auth header but no token - no user ID
      return;
    }

    // Try custom user ID provider first
    if (_config.userIdProvider != null) {
      try {
        final userId = await _config.userIdProvider!(token);
        if (userId != null && userId.isNotEmpty) {
          options.extra['_acdc_user_id'] = userId;
          return;
        }
      } on Exception catch (_) {
        // Custom provider failed - fall through to JWT extraction
      }
    }

    // Extract user ID from JWT
    final userId = JwtUtils.extractUserId(token);
    if (userId != null && userId.isNotEmpty) {
      options.extra['_acdc_user_id'] = userId;
    }
    // If no user ID found but has auth, caching will be disabled (security)
  }

  /// Extracts the token from Authorization header.
  ///
  /// Handles common formats:
  /// - "Bearer {token}"
  /// - "{token}"
  String? _extractToken(String authHeader) {
    final trimmed = authHeader.trim();

    // Handle "Bearer token" format
    if (trimmed.toLowerCase().startsWith('bearer ')) {
      final token = trimmed.substring(7).trim();
      return token.isNotEmpty ? token : null;
    }

    // Handle direct token format
    return trimmed.isNotEmpty ? trimmed : null;
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    // Invalidate cache for mutation requests (POST/PUT/DELETE/PATCH)
    final method = response.requestOptions.method.toUpperCase();
    if (_isMutationMethod(method)) {
      _invalidateCacheForUrl(response.requestOptions.uri.toString());
    }

    // Add cache metadata to response
    _addCacheMetadata(response);

    // Delegate to dio_cache_interceptor
    _dioCacheInterceptor.onResponse(response, handler);
  }

  /// Adds cache metadata to response.
  ///
  /// Adds:
  /// - X-ACDC-From-Cache header when response came from cache
  /// - response.extra['fromOfflineCache'] flag (set in onError for offline scenarios)
  void _addCacheMetadata(Response<dynamic> response) {
    // Check if response came from cache
    // dio_cache_interceptor adds CacheResponse.cacheKey to extra when serving from cache
    final fromCache = response.extra[CacheResponse.cacheKey] != null;

    if (fromCache) {
      // Add X-ACDC-From-Cache header
      response.headers.add('X-ACDC-From-Cache', 'true');

      // Note: fromOfflineCache flag is set in onError when serving
      // stale cache during network failures
    }
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    // Create a custom error handler to detect when cache is served during network errors
    final customHandler = _CacheAwareErrorHandler(
      originalHandler: handler,
      originalError: err,
    );

    // Delegate to dio_cache_interceptor (may serve stale cache on network error)
    _dioCacheInterceptor.onError(err, customHandler);
  }

  /// Clears all cached entries.
  Future<void> clearCache() async {
    await _cacheOptions.store?.clean();
  }

  /// Clears cached entries for a specific URL.
  Future<void> clearCacheForUrl(String url) async {
    final key = CacheOptions.defaultCacheKeyBuilder(
      RequestOptions(path: url),
    );
    await _cacheOptions.store?.delete(key);
  }

  /// Checks if the HTTP method is a mutation (POST/PUT/DELETE/PATCH).
  bool _isMutationMethod(String method) =>
      method == 'POST' ||
      method == 'PUT' ||
      method == 'DELETE' ||
      method == 'PATCH';

  /// Invalidates cache for a specific URL (fire-and-forget).
  void _invalidateCacheForUrl(String url) {
    // Fire-and-forget cache invalidation
    clearCacheForUrl(url).catchError((_) {
      // Silently ignore cache invalidation errors
      // Cache invalidation is best-effort
    });
  }
}

/// Custom error handler that adds cache metadata when serving from offline cache.
///
/// Wraps the original error handler to detect when dio_cache_interceptor
/// serves stale cache during network errors, and adds appropriate metadata.
class _CacheAwareErrorHandler extends ErrorInterceptorHandler {
  _CacheAwareErrorHandler({
    required this.originalHandler,
    required this.originalError,
  });

  final ErrorInterceptorHandler originalHandler;
  final DioException originalError;

  @override
  void next(DioException err) {
    // dio_cache_interceptor called next() - no cache was served
    // Check if the original error was a network error and enhance it
    final isNetworkError =
        originalError.type == DioExceptionType.connectionTimeout ||
            originalError.type == DioExceptionType.sendTimeout ||
            originalError.type == DioExceptionType.receiveTimeout ||
            originalError.type == DioExceptionType.connectionError;

    if (isNetworkError) {
      // Enhance network exception with ACDC exception
      originalHandler.reject(
        AcdcNetworkException.fromDioException(originalError),
      );
    } else {
      // Pass through other errors
      originalHandler.next(err);
    }
  }

  @override
  void reject(DioException err) {
    // dio_cache_interceptor explicitly rejected - pass through
    originalHandler.reject(err);
  }

  @override
  void resolve(Response<dynamic> response) {
    // Response was served from cache during network error (offline scenario)
    // Add offline cache metadata
    response.extra['fromOfflineCache'] = true;
    response.headers.add('X-ACDC-From-Cache', 'true');

    originalHandler.resolve(response);
  }
}
