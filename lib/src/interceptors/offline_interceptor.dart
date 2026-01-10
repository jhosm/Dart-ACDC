import 'dart:async';

import 'package:dart_acdc/src/cache/cache_config.dart';
import 'package:dart_acdc/src/exceptions/acdc_network_exception.dart';
import 'package:dart_acdc/src/interceptors/cache_interceptor.dart';
import 'package:dart_acdc/src/network_info/network_info.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

/// Interceptor to handle offline connectivity states.
///
/// Functionality:
/// - Detects if the device is offline using [NetworkInfo].
/// - Fails fast if offline and `failFast` is true (default).
/// - Attempts to return cached data if offline, even if cache is stale (if configured).
/// - Bypasses checks if `force_network` is true in request options.
class OfflineInterceptor extends Interceptor {
  /// Creates an offline interceptor.
  OfflineInterceptor({
    required this.networkInfo,
    this.cacheStore,
    this.cacheConfig,
    this.failFast = true,
  });

  /// The network info provider.
  final NetworkInfo networkInfo;

  /// Optional cache store to retrieve data when offline.
  final CacheStore? cacheStore;

  /// Optional cache configuration.
  final CacheConfig? cacheConfig;

  /// Whether to throw an exception immediately when offline (if no cache available).
  final bool failFast;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 1. Check if forced network
    final forceNetwork = options.extra['force_network'] as bool? ?? false;
    if (forceNetwork) {
      handler.next(options);
      return;
    }

    // 2. Check connectivity
    if (networkInfo.isConnected) {
      handler.next(options);
      return;
    }

    // 3. Device is offline

    // Try to retrieve from cache if available
    if (cacheStore != null && cacheConfig != null) {
      final cachedResponse = await _tryGetFromCache(options);
      if (cachedResponse != null) {
        handler.resolve(cachedResponse);
        return;
      }
    }

    // No cache available (or cache store not configured)

    if (failFast) {
      // Create a dummy DioException to wrap
      final dioException = DioException(
        requestOptions: options,
        error: 'No internet connection',
        type: DioExceptionType.connectionError,
      );

      handler.reject(
        AcdcNetworkException.fromDioException(dioException),
      );
    } else {
      // Proceed (let Dio or other interceptors handle it, though it will likely fail)
      handler.next(options);
    }
  }

  Future<Response<dynamic>?> _tryGetFromCache(RequestOptions options) async {
    // Only GET/HEAD requests are cached usually
    if (options.method != 'GET' && options.method != 'HEAD') {
      return null;
    }

    try {
      // Use the same key generation strategy as AcdcCacheInterceptor
      final key = AcdcCacheInterceptor.buildCacheKeyWithUserIsolation(
        options,
        customKeyBuilder: cacheConfig?.keyBuilder,
      );

      // If key is empty, caching is disabled for this request (e.g. auth required but missing)
      if (key.isEmpty) return null;

      final cachedResponse = await cacheStore!.get(key);

      if (cachedResponse != null) {
        // Convert to Dio response
        // We allow stale content since we are offline
        final response = cachedResponse.toResponse(options);

        // Add metadata
        response.extra['fromOfflineCache'] = true;
        response.extra['from_cache'] = true;
        response.headers.add('X-ACDC-From-Cache', 'true');

        // Set 200 OK because we are successfully returning data (even if stale)
        response.statusCode = 200;

        return response;
      }
    } catch (e) {
      // Ignore cache errors, proceed to fail fast
    }
    return null;
  }
}
