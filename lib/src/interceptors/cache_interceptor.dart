import 'dart:async';

import 'package:dart_acdc/src/cache/cache_config.dart';
import 'package:dart_acdc/src/cache/cache_store_factory.dart'
    show CacheStoreFactory;
import 'package:dart_acdc/src/exceptions/acdc_network_exception.dart';
import 'package:dart_acdc/src/logging/acdc_log_delegate.dart';
import 'package:dart_acdc/src/logging/log_level.dart';
import 'package:dart_acdc/src/security/user_id_extractor.dart';
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
  /// Creates a cache interceptor from configuration and cache store.
  ///
  /// The [store] parameter should be created using [CacheStoreFactory]
  /// which handles platform-specific store creation:
  /// - Uses in-memory cache with configured size limits
  /// - Optionally encrypts cache with platform secure storage
  /// - Supports two-tier caching (memory + persistent)
  ///
  /// Cache policies are configured based on [config] flags:
  /// - Only caches GET and HEAD requests
  /// - Invalidates cache on POST/PUT/DELETE/PATCH requests
  /// - Requires user ID extraction for caching (user isolation)
  AcdcCacheInterceptor({
    required CacheConfig config,
    required CacheStore store,
    this.onRefresh,
    this.logDelegate,
  }) : _config = config {
    _cacheOptions = CacheOptions(
      store: store,
      // Always use request policy if SWR is enabled, as we handle SWR manually
      policy: config.staleWhileRevalidate
          ? CachePolicy.request
          : CachePolicy.request,
      maxStale: (config.staleIfError || config.staleWhileRevalidate)
          ? const Duration(days: 7)
          : null,
      hitCacheOnErrorCodes: config.staleIfError ? [401, 403] : [],
      keyBuilder: ({required url, headers, body}) {
        // Build base key using custom builder or default
        final baseKey = config.keyBuilder != null
            ? config.keyBuilder!(
                RequestOptions(
                  path: url.toString(),
                  headers: headers,
                ),
              )
            : CacheOptions.defaultCacheKeyBuilder(
                url: url,
                headers: headers,
                body: body,
              );

        // Add user isolation suffix if user ID header is present
        final userId = headers?['X-ACDC-User-Id'];
        if (userId != null && userId.isNotEmpty) {
          return '$baseKey:$userId';
        }
        return baseKey;
      },
    );

    _dioCacheInterceptor = DioCacheInterceptor(
      options: CacheOptions(
        store: store,
        policy: config.staleWhileRevalidate
            ? CachePolicy.request
            : CachePolicy.request,
        maxStale: (config.staleIfError || config.staleWhileRevalidate)
            ? const Duration(days: 7)
            : null,
        hitCacheOnErrorCodes: config.staleIfError ? [401, 403] : [],
        keyBuilder: ({required url, headers, body}) {
          // Build base key using custom builder or default
          final baseKey = config.keyBuilder != null
              ? config.keyBuilder!(
                  RequestOptions(
                    path: url.toString(),
                    headers: headers,
                  ),
                )
              : CacheOptions.defaultCacheKeyBuilder(
                  url: url,
                  headers: headers,
                  body: body,
                );

          // Add user isolation suffix if user ID header is present
          final userId = headers?['X-ACDC-User-Id'];
          if (userId != null && userId.isNotEmpty) {
            return '$baseKey:$userId';
          }
          return baseKey;
        },
      ),
    );
  }

  /// Callback to trigger background refresh (SWR).
  final Future<dynamic> Function(RequestOptions)? onRefresh;

  /// Optional delegate for detailed cache logging.
  final AcdcLogDelegate? logDelegate;

  final CacheConfig _config;
  late final CacheOptions _cacheOptions;
  late final DioCacheInterceptor _dioCacheInterceptor;

  /// Returns the underlying cache store.
  CacheStore? get store => _cacheOptions.store;

  /// Builds a cache key with user isolation.
  ///
  /// Returns:
  /// - Unauthenticated: Standard key (shared cache)
  /// - Authenticated with user ID: `{baseKey}:{userId}` (user-isolated)
  /// - Authenticated without user ID: Empty string (no caching)
  ///
  /// The user ID is read from `X-ACDC-User-Id` header (normal flow)
  /// or from `options.extra['_acdc_user_id']` (testing/backward compat).
  ///
  /// This method is public to enable testing but should not be called directly
  /// by library users.
  static String buildCacheKeyWithUserIsolation(
    RequestOptions options, {
    String Function(RequestOptions)? customKeyBuilder,
  }) {
    // Build base cache key
    final baseKey = customKeyBuilder?.call(options) ??
        CacheOptions.defaultCacheKeyBuilder(
          url: Uri.parse(options.uri.toString()),
          headers: options.headers
              .map((key, value) => MapEntry(key, value.toString())),
          body: options.data,
        );

    // Check for user ID in header first, then fall back to extra for backward compat
    final userId = options.headers['X-ACDC-User-Id']?.toString() ??
        options.extra['_acdc_user_id'] as String?;
    final hasAuth = options.extra['_acdc_has_auth'] as bool? ?? false;

    if (!hasAuth && userId == null) {
      // No auth - unauthenticated, use shared cache
      return baseKey;
    }

    if (hasAuth && (userId == null || userId.isEmpty)) {
      // Authenticated but no user ID - disable caching for security
      return '';
    }

    if (userId != null && userId.isNotEmpty) {
      // Authenticated with user ID - use user-isolated cache
      return '$baseKey:$userId';
    }

    // Default: use shared cache
    return baseKey;
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Extract user ID from Authorization header for cache isolation
    await _extractAndStoreUserId(options);

    // Handle Stale-While-Revalidate manually logic
    if (_config.staleWhileRevalidate &&
        options.method.toUpperCase() == 'GET' &&
        options.extra['swr_refresh'] != true) {
      final key = buildCacheKeyWithUserIsolation(
        options,
        customKeyBuilder: _config.keyBuilder,
      );

      final cachedResponse = await _cacheOptions.store?.get(key);

      if (cachedResponse != null) {
        logDelegate?.log(
          'Cache Hit (SWR): ${options.uri}',
          LogLevel.info,
          {
            'type': 'cache_hit',
            'subtype': 'swr_initial',
            'key': key,
            'url': options.uri.toString(),
            'method': options.method,
          },
        );
        // Serve stale cache immediately
        final response = cachedResponse.toResponse(options)..statusCode = 200;
        // Important: Update status code to 200, as it might be stored differently
        response.extra['acdc_source'] = 'cache_stale';

        // Add metadata
        _addCacheMetadata(response);

        // Resolve request
        handler.resolve(response);

        // Trigger background refresh
        // Copy options and force refresh policy via extra
        final refreshOptions = options.copyWith(
          extra: _cacheOptions
              .copyWith(policy: CachePolicy.refreshForceCache)
              .toExtra()
            ..['swr_refresh'] = true, // Prevent infinite loop
        );

        // Use onRefresh callback if provided
        // We use Future.microtask to ensure it's detached from current flow
        if (onRefresh != null) {
          final refreshFuture = onRefresh!(refreshOptions);

          // Allow catching the refresh future via callback (for streamRequest support)
          final swrCallback =
              options.extra['swr_callback'] as void Function(Future<dynamic>)?;
          if (swrCallback != null) {
            swrCallback(refreshFuture);
          }

          Future.microtask(() => refreshFuture).catchError((e) {
            // Ignore background refresh errors
            // Optionally log if we had a logger reference
          }).ignore();
        }
        return;
      }
    }

    // Delegate to dio_cache_interceptor with custom handler to intercept cache hits
    _dioCacheInterceptor.onRequest(
      options,
      _CacheAwareRequestHandler(
        handler: handler,
        logDelegate: logDelegate,
      ),
    );
  }

  /// Extracts user ID from Authorization header and stores it.
  ///
  /// Stores the user ID in:
  /// - `X-ACDC-User-Id` header (used by cache keyBuilder)
  /// - `options.extra['_acdc_user_id']` (for backward compatibility/testing)
  /// - `options.extra['_acdc_has_auth']` (auth presence flag)
  ///
  /// This enables proper cache key generation:
  /// - No auth → shared cache
  /// - Auth + user ID → user-isolated cache (key includes user ID)
  /// - Auth but no user ID → no caching (empty key)
  Future<void> _extractAndStoreUserId(RequestOptions options) async {
    final extractor = UserIdExtractor(userIdProvider: _config.userIdProvider);
    final authHeader = options.headers['Authorization']?.toString();

    final result = await extractor.extract(authHeader);

    options.extra['_acdc_has_auth'] = result.hasAuth;

    if (!result.hasAuth) {
      // No auth header - will use shared cache
      return;
    }

    final userId = result.userId;
    if (userId != null && userId.isNotEmpty) {
      // Authenticated with user ID
      options.headers['X-ACDC-User-Id'] = userId;
      options.extra['_acdc_user_id'] = userId;
    } else {
      // Auth present but no user ID - disable caching for security
      options.headers['X-ACDC-User-Id'] = '';
    }
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

    // Handle 304 Not Modified manually if it wasn't treated as an error
    // (e.g. if validateStatus allows 304)
    if (response.statusCode == 304) {
      _resolve304Response(
        response.requestOptions,
      ).then((cachedResponse) {
        if (cachedResponse != null) {
          handler.resolve(cachedResponse);
          return;
        }
        // If not found in cache, fall through to standard handling
        _proceedWithResponse(response, handler);
      });
      return;
    }

    _proceedWithResponse(response, handler);
  }

  void _proceedWithResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    // Add cache metadata to response
    _addCacheMetadata(response);

    // Delegate to dio_cache_interceptor
    _dioCacheInterceptor.onResponse(response, handler);

    // Determine and set acdc_source for network responses
    // We only set this if it wasn't already set (e.g. by cache logic)
    // Determine and set acdc_source for network responses
    // We only set this if it wasn't already set (e.g. by cache logic)
    if (response.extra['acdc_source'] == null) {
      final fromCache = response.extra['from_cache'] as bool? ?? false;
      // Check if response came from cache via dio_cache_interceptor logic
      final isDioCacheHit = response.extra[extraCacheKey] != null;

      if (fromCache || isDioCacheHit) {
        response.extra['acdc_source'] = 'cache';
        // Ensure consistency
        response.extra['from_cache'] = true;
      } else {
        final isSwrRefresh =
            response.requestOptions.extra['swr_refresh'] == true;
        response.extra['acdc_source'] =
            isSwrRefresh ? 'network_fresh' : 'network';
      }
    }

    // If response was not from cache, it is likely being written to cache
    // (dio_cache_interceptor handles logic, but if we got here, we are passing it down)
    final fromCache = response.extra['from_cache'] as bool? ?? false;
    if (!fromCache &&
        (response.requestOptions.method == 'GET' ||
            response.requestOptions.method == 'HEAD')) {
      logDelegate?.log(
        'Cache Write: ${response.requestOptions.uri}',
        LogLevel.info,
        {
          'type': 'cache_write',
          'url': response.requestOptions.uri.toString(),
          'method': response.requestOptions.method,
          'status': response.statusCode,
          'key': _cacheOptions.keyBuilder(
            url: response.requestOptions.uri,
            headers: response.requestOptions.headers
                .map((key, value) => MapEntry(key, value.toString())),
            body: response.requestOptions.data,
          ),
        },
      );
    }
  }

  /// Adds cache metadata to response.
  ///
  /// Adds:
  /// - X-ACDC-From-Cache header when response came from cache
  /// - response.extra['fromOfflineCache'] flag (set in onError for offline scenarios)
  void _addCacheMetadata(Response<dynamic> response) {
    // Check if response came from cache
    // dio_cache_interceptor adds extraCacheKey to extra when serving from cache
    final fromCache = response.extra[extraCacheKey] != null;

    if (fromCache) {
      // Add X-ACDC-From-Cache header if not already present
      if (response.headers.value('X-ACDC-From-Cache') == null) {
        response.headers.add('X-ACDC-From-Cache', 'true');
      }

      // Note: fromOfflineCache flag is set in onError when serving
      // stale cache during network failures
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Handle 304 Not Modified manually if dio_cache_interceptor misses it
    if (err.response?.statusCode == 304) {
      final cachedResponse = await _resolve304Response(err.requestOptions);
      if (cachedResponse != null) {
        handler.resolve(cachedResponse);
        return;
      }
    }

    // Create a custom error handler to detect when cache is served during network errors
    final customHandler = _CacheAwareErrorHandler(
      originalHandler: handler,
      originalError: err,
    );

    // Delegate to dio_cache_interceptor (may serve stale cache on network error)
    _dioCacheInterceptor.onError(err, customHandler);
  }

  /// Attempts to resolve a 304 Not Modified response from the cache.
  Future<Response<dynamic>?> _resolve304Response(
    RequestOptions requestOptions,
  ) async {
    try {
      final key = buildCacheKeyWithUserIsolation(
        requestOptions,
        customKeyBuilder: _config.keyBuilder,
      );

      final cachedResponse = await _cacheOptions.store?.get(key);

      if (cachedResponse != null) {
        final response = cachedResponse.toResponse(requestOptions)
          ..statusCode = 200;

        response.extra['acdc_source'] = 'cache';
        _addCacheMetadata(response);
        return response;
      }
    } on Exception catch (_) {
      // Fallback to standard handling on error
    }
    return null;
  }

  /// Clears all cached entries.
  Future<void> clearCache() async {
    await _cacheOptions.store?.clean();
  }

  /// Clears cached entries for a specific URL.
  ///
  /// This method clears both the shared cache entry and all user-isolated
  /// cache entries for the given URL. User-isolated entries have keys in the
  /// format `baseKey:userId` but share the same URL.
  ///
  /// Uses pattern-based deletion to remove all cache entries with matching URLs.
  Future<void> clearCacheForUrl(String url) async {
    // Escape special regex characters in the URL
    final escapedUrl = RegExp.escape(url);

    // Create a pattern that matches the exact URL
    // deleteFromPath matches against the URL field in cache entries,
    // so this will match both shared and user-isolated entries
    final pattern = RegExp('^$escapedUrl\$');

    // Use deleteFromPath to clear all matching entries
    await _cacheOptions.store?.deleteFromPath(pattern);
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

/// Handler to intercept cache hits from dio_cache_interceptor.onRequest.
class _CacheAwareRequestHandler extends RequestInterceptorHandler {
  _CacheAwareRequestHandler({
    required this.handler,
    this.logDelegate,
  });

  final RequestInterceptorHandler handler;
  final AcdcLogDelegate? logDelegate;

  @override
  void next(RequestOptions options) {
    // dio_cache_interceptor called next() - implies cache miss or cache skip
    logDelegate?.log(
      'Cache Miss: ${options.uri}',
      LogLevel.info,
      {
        'type': 'cache_miss',
        'url': options.uri.toString(),
        'method': options.method,
      },
    );
    handler.next(options);
  }

  @override
  void resolve(
    Response<dynamic> response, [
    bool callFollowingResponseInterceptor = false,
  ]) {
    // This is called when dio_cache_interceptor finds a valid cache entry.
    // Mark the response as being from cache.
    response.extra['from_cache'] = true;
    response.extra['acdc_source'] = 'cache';
    response.headers.add('X-ACDC-From-Cache', 'true');

    logDelegate?.log(
      'Cache Hit (Intercepted): ${response.requestOptions.uri}',
      LogLevel.info,
      {
        'type': 'cache_hit',
        'subtype': 'intercepted',
        'url': response.requestOptions.uri.toString(),
        'method': response.requestOptions.method,
      },
    );

    handler.resolve(response, callFollowingResponseInterceptor);
  }

  @override
  void reject(
    DioException error, [
    bool callFollowingErrorInterceptor = false,
  ]) {
    handler.reject(error, callFollowingErrorInterceptor);
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
    response.extra['from_cache'] = true;
    response.extra['acdc_source'] = 'cache';
    response.headers.add('X-ACDC-From-Cache', 'true');

    originalHandler.resolve(response);
  }
}
