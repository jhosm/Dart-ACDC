import 'package:dart_acdc/src/interceptors/cache_interceptor.dart';
import 'package:dio/dio.dart';

/// Manager for cache operations.
///
/// Provides methods for:
/// - Clearing cached responses globally
/// - Clearing cached responses for specific URLs
///
/// Accessible via `dio.cache` extension.
class AcdcCacheManager {
  /// Internal constructor.
  AcdcCacheManager({
    required AcdcCacheInterceptor? cacheInterceptor,
  }) : _cacheInterceptor = cacheInterceptor;

  final AcdcCacheInterceptor? _cacheInterceptor;

  /// Clears all cached HTTP responses.
  ///
  /// **Usage**:
  /// ```dart
  /// await dio.cache.clearCache();
  /// ```
  Future<void> clearCache() async {
    if (_cacheInterceptor != null) {
      await _cacheInterceptor.clearCache();
    }
  }

  /// Clears cached responses for a specific URL.
  ///
  /// **Usage**:
  /// ```dart
  /// await dio.cache.clearCacheForUrl('https://api.example.com/users');
  /// ```
  Future<void> clearCacheForUrl(String url) async {
    if (_cacheInterceptor != null) {
      await _cacheInterceptor.clearCacheForUrl(url);
    }
  }
}

/// Extension on [Dio] to access cache manager.
extension AcdcCache on Dio {
  /// Gets the cache manager for this Dio instance.
  AcdcCacheManager get cache {
    final manager = options.extra['_acdc_cache_manager'] as AcdcCacheManager?;
    if (manager == null) {
      // Return a dummy manager if not configured, or throw?
      // Given we support disableAuth where auth manager is present but limited,
      // and disableCache where cache is bypassed, we should probably always provide a manager
      // that might just be no-op if cache is disabled.

      // However, client builder should always inject it.
      // If manually attached, it might be missing.
      throw StateError(
        'AcdcCacheManager not initialized. Ensure you are using AcdcClientBuilder.',
      );
    }
    return manager;
  }
}
