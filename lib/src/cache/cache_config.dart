/// Configuration for HTTP response caching.
library;

import 'package:dio/dio.dart';

/// Configuration for HTTP response caching.
///
/// Defines caching behavior including TTL, size limits, encryption, and
/// user isolation settings.
class CacheConfig {
  /// Creates a cache configuration.
  ///
  /// All parameters are optional and have sensible defaults:
  /// - [ttl]: Cache entry time-to-live (default: 1 hour)
  /// - [maxSize]: Maximum cache size in bytes (default: 10 MB)
  /// - [cacheAuthenticatedRequests]: Whether to cache authenticated requests (default: true)
  /// - [inMemory]: Enable in-memory cache layer (default: true)
  /// - [inMemoryMaxSize]: Maximum in-memory cache size in bytes (default: 5 MB)
  /// - [staleWhileRevalidate]: Serve stale cache while refreshing (default: false)
  /// - [staleIfError]: Serve stale cache on network errors (default: true)
  /// - [staleIfErrorCodes]: HTTP status codes that trigger stale cache (default: server errors only)
  /// - [userIdProvider]: Custom user ID extraction for non-JWT auth
  const CacheConfig({
    this.ttl = const Duration(hours: 1),
    this.maxSize = 10 * 1024 * 1024, // 10 MB
    this.cacheAuthenticatedRequests = true,
    this.inMemory = true,
    this.inMemoryMaxSize = 5 * 1024 * 1024, // 5 MB
    this.staleWhileRevalidate = false,
    this.staleIfError = true,
    this.staleIfErrorCodes = const [500, 502, 503, 504],
    this.userIdProvider,
    this.keyBuilder,
    this.version,
    this.onError,
    this.storePath,
  });

  /// Custom path for cache storage.
  ///
  /// If provided, overrides the default location (Application Documents Directory).
  /// Useful for testing or when a specific storage location is required.
  final String? storePath;

  /// Custom cache key builder.
  ///
  /// Allows customizing how cache keys are generated from requests.
  /// If provided, this is used instead of the default key builder.
  /// User isolation is still enforced by appending the user ID to the
  /// custom key for authenticated requests.
  final String Function(RequestOptions request)? keyBuilder;

  /// Cache entry time-to-live.
  ///
  /// Determines how long responses are cached before expiring.
  /// Defaults to 1 hour.
  final Duration ttl;

  /// Maximum cache size in bytes.
  ///
  /// When exceeded, least recently used entries are evicted.
  /// Defaults to 10 MB.
  final int maxSize;

  /// Whether to cache authenticated requests.
  ///
  /// When true, requests with authentication tokens are cached with
  /// user-based isolation to prevent data leakage.
  /// Defaults to true.
  final bool cacheAuthenticatedRequests;

  /// Enable in-memory cache layer.
  ///
  /// When true, adds a memory cache before disk cache for faster access.
  /// Defaults to true.
  final bool inMemory;

  /// Maximum in-memory cache size in bytes.
  ///
  /// Only applies when [inMemory] is true.
  /// Defaults to 5 MB.
  final int inMemoryMaxSize;

  /// Serve stale cache while revalidating.
  ///
  /// When true, returns stale cached response immediately while
  /// fetching fresh data in the background.
  /// Defaults to false.
  final bool staleWhileRevalidate;

  /// Serve stale cache on network errors.
  ///
  /// When true, returns stale cached response if network request fails.
  /// Defaults to true.
  final bool staleIfError;

  /// HTTP status codes that trigger stale cache when [staleIfError] is true.
  ///
  /// Only applies when [staleIfError] is enabled. When the server responds
  /// with one of these status codes, the cache interceptor will serve stale
  /// cached content instead of propagating the error.
  ///
  /// Defaults to server errors only: `[500, 502, 503, 504]`.
  ///
  /// **Important**: Including client errors like 401 (Unauthorized) or
  /// 403 (Forbidden) may mask authentication failures and prevent proper
  /// token refresh. Only include auth-related codes if you understand the
  /// implications for your auth flow.
  final List<int> staleIfErrorCodes;

  /// Custom user ID provider for non-JWT authentication.
  ///
  /// Used to extract user ID from access tokens that aren't JWTs.
  /// If null, user ID is extracted from JWT claims (sub, user_id, uid).
  final Future<String?> Function(String accessToken)? userIdProvider;

  /// Cache version string.
  ///
  /// Changing this value invalidates the entire cache.
  /// Used for handling breaking changes or major updates.
  final String? version;

  /// Callback for cache errors.
  ///
  /// Called when internal cache operations fail (e.g., encryption errors,
  /// storage failures).
  final void Function(Object error, StackTrace stackTrace)? onError;

  @override
  String toString() => 'CacheConfig('
      'ttl: $ttl, '
      'maxSize: $maxSize, '
      'cacheAuthenticatedRequests: $cacheAuthenticatedRequests, '
      'inMemory: $inMemory, '
      'inMemoryMaxSize: $inMemoryMaxSize, '
      'staleWhileRevalidate: $staleWhileRevalidate, '
      'staleIfError: $staleIfError, '
      'staleIfErrorCodes: $staleIfErrorCodes, '
      'hasUserIdProvider: ${userIdProvider != null}, '
      'hasKeyBuilder: ${keyBuilder != null}, '
      'version: $version)';
}
