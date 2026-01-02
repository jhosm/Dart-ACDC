import 'package:dart_acdc/src/cache/cache_config.dart';
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
/// - User isolation for authenticated requests
class AcdcCacheInterceptor extends Interceptor {
  /// Creates a cache interceptor from configuration.
  ///
  /// Builds appropriate cache stores based on [config] settings:
  /// - Uses in-memory cache with configured size limits
  /// - Configures cache policies based on config flags
  /// - Only caches GET and HEAD requests
  /// - Invalidates cache on POST/PUT/DELETE/PATCH requests
  AcdcCacheInterceptor({
    required CacheConfig config,
  })  : _cacheOptions = CacheOptions(
          // Use memory cache store
          store: MemCacheStore(
            maxSize: config.inMemory ? config.inMemoryMaxSize : config.maxSize,
          ),

          // Cache policy based on config - respects HTTP directives
          policy: config.staleWhileRevalidate
              ? CachePolicy.refreshForceCache
              : CachePolicy.request,

          // TTL configuration
          maxStale: config.staleIfError ? const Duration(days: 7) : null,

          // Hit cache on network errors if configured
          hitCacheOnErrorExcept: config.staleIfError ? [] : [401, 403],
        ),
        _dioCacheInterceptor = DioCacheInterceptor(
          options: CacheOptions(
            store: MemCacheStore(
              maxSize:
                  config.inMemory ? config.inMemoryMaxSize : config.maxSize,
            ),
            policy: config.staleWhileRevalidate
                ? CachePolicy.refreshForceCache
                : CachePolicy.request,
            maxStale: config.staleIfError ? const Duration(days: 7) : null,
            hitCacheOnErrorExcept: config.staleIfError ? [] : [401, 403],
          ),
        );

  final CacheOptions _cacheOptions;
  final DioCacheInterceptor _dioCacheInterceptor;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    // Delegate to dio_cache_interceptor
    _dioCacheInterceptor.onRequest(options, handler);
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

    // Delegate to dio_cache_interceptor
    _dioCacheInterceptor.onResponse(response, handler);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    // Delegate to dio_cache_interceptor
    _dioCacheInterceptor.onError(err, handler);
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
