# Caching Specification

## ADDED Requirements

### Requirement: HTTP Cache Headers Support

The library SHALL respect standard HTTP cache headers (Cache-Control, ETag, Last-Modified) for response caching.

#### Scenario: Cache-Control header respected

- **WHEN** a response includes a `Cache-Control: max-age=3600` header
- **THEN** the response is cached for 3600 seconds
- **AND** subsequent identical requests within the time window return the cached response

#### Scenario: ETag-based conditional request

- **WHEN** a cached response includes an ETag header
- **AND** a new request is made for the same resource
- **THEN** an `If-None-Match` header is added with the ETag value
- **AND** the server returns 304 Not Modified if the resource hasn't changed
- **AND** the cached response is returned

#### Scenario: No-cache directive

- **WHEN** a response includes `Cache-Control: no-cache` or `no-store`
- **THEN** the response is not cached
- **AND** subsequent requests always hit the network

### Requirement: HTTP Method-Based Caching

The library SHALL only cache responses from safe HTTP methods and invalidate cache on mutating operations.

#### Scenario: Only GET requests are cached

- **WHEN** a GET request is made
- **THEN** the response is eligible for caching based on cache headers
- **AND** the cached response can be returned for subsequent identical GET requests

#### Scenario: HEAD requests use GET cache

- **WHEN** a HEAD request is made for a resource
- **AND** a cached GET response exists for the same resource
- **THEN** the cached response headers are returned
- **AND** the response body is omitted

#### Scenario: Mutating requests not cached

- **WHEN** a POST, PUT, PATCH, or DELETE request is made
- **THEN** the request is never cached
- **AND** the request always hits the network
- **AND** the response is never stored in cache

#### Scenario: Cache invalidation on mutation

- **WHEN** a POST, PUT, PATCH, or DELETE request succeeds
- **THEN** cached GET responses for the same URL are invalidated
- **AND** related cached responses remain until explicit invalidation

### Requirement: Default Cache Configuration

The library SHALL enable caching by default with sensible settings that work for most mobile apps.

#### Scenario: Default cache enabled

- **WHEN** a Dio instance is created without cache configuration
- **THEN** caching is enabled with default settings
- **AND** the cache TTL is 1 hour for cacheable responses
- **AND** the maximum cache size is 10 MB

#### Scenario: Cache opt-out

- **WHEN** a developer calls `AcdcClientBuilder().disableCache()`
- **THEN** no cache interceptor is added
- **AND** all requests bypass caching

### Requirement: Cache Policy Configuration

The library SHALL allow developers to configure cache behavior with custom policies.

#### Scenario: Custom TTL configuration

- **WHEN** a developer configures cache with custom TTL
- **THEN** cached responses expire after the specified duration
- **AND** expired entries are automatically removed

```dart
final dio = AcdcClientBuilder()
  .withCache(CacheConfig(
    ttl: Duration(hours: 24),
  ))
  .build();
```

#### Scenario: Custom cache size limit

- **WHEN** a developer configures maximum cache size
- **THEN** the cache stores up to the specified size
- **AND** least recently used (LRU) entries are evicted when the limit is reached
- **AND** access time is updated on cache reads

```dart
final dio = AcdcClientBuilder()
  .withCache(CacheConfig(
    maxSize: 50 * 1024 * 1024, // 50 MB
  ))
  .build();
```

#### Scenario: LRU eviction policy

- **WHEN** the cache reaches its size limit
- **AND** a new response needs to be cached
- **THEN** the least recently accessed entry is removed first
- **AND** cache size is reduced to make room for the new entry
- **AND** eviction continues until sufficient space is available

### Requirement: Cache Invalidation

The library SHALL provide methods to clear cached responses when needed.

#### Scenario: Clear all cache

- **WHEN** a developer calls `clearCache()` on the cache manager
- **THEN** all cached responses are removed
- **AND** subsequent requests hit the network

#### Scenario: Clear specific URL cache

- **WHEN** a developer calls `clearCacheForUrl(url)`
- **THEN** cached responses for that URL are removed
- **AND** other cached responses remain intact

#### Scenario: Automatic cache clear on logout

- **WHEN** the user logs out via the authentication system
- **THEN** all cached responses are automatically cleared
- **AND** the in-memory cache is cleared
- **AND** the persistent disk cache is cleared
- **AND** subsequent login starts with a fresh cache

#### Scenario: Cache clear on app version change

- **WHEN** the app version changes (detected on startup)
- **THEN** all cached responses are automatically cleared
- **AND** the new version starts with a fresh cache
- **AND** this prevents schema incompatibilities from cached data

### Requirement: Stale-While-Revalidate Support

The library SHALL support serving stale cache data while revalidating in the background.

#### Scenario: Stale cache served immediately

- **WHEN** a cached response has expired
- **AND** stale-while-revalidate is enabled
- **THEN** the stale cached response is returned immediately
- **AND** a background request is made to refresh the cache

#### Scenario: Background cache update

- **WHEN** a stale response is served
- **AND** the background refresh completes
- **THEN** the cache is updated with the fresh response
- **AND** subsequent requests use the fresh cache

### Requirement: Offline Network Handling

The library SHALL serve cached responses when the network is unavailable to enable offline functionality.

#### Scenario: Network unavailable fallback

- **WHEN** a request fails due to network unavailability
- **AND** a cached response exists (even if expired)
- **THEN** the cached response is returned
- **AND** response metadata indicates the data is from offline cache

#### Scenario: Network unavailable with no cache

- **WHEN** a request fails due to network unavailability
- **AND** no cached response exists
- **THEN** a NetworkUnavailableError is thrown
- **AND** the error message indicates offline state

#### Scenario: Network quality detection

- **WHEN** the network connection is detected
- **THEN** the library adjusts timeout values based on connection type
- **AND** slower connections get longer timeouts
- **AND** requests are not prematurely cancelled on slow networks

### Requirement: Persistent Cache Storage

The library SHALL store cached responses persistently to disk for offline access.

#### Scenario: Cache persists across app restarts

- **WHEN** responses are cached
- **AND** the app is restarted
- **THEN** cached responses are still available
- **AND** expired entries are removed on startup

#### Scenario: Cache directory location

- **WHEN** the library initializes cache storage
- **THEN** cache files are stored in the app's cache directory
- **AND** the cache directory is excluded from app backups

### Requirement: In-Memory Cache Layer

The library SHALL provide an optional in-memory cache layer for fast access to frequently requested data.

#### Scenario: In-memory cache for fast access

- **WHEN** a developer enables in-memory caching
- **THEN** responses are cached in memory before writing to disk
- **AND** subsequent requests check the memory cache first
- **AND** memory cache hits return immediately without disk I/O

#### Scenario: Memory cache eviction

- **WHEN** the in-memory cache reaches its size limit
- **THEN** least recently used entries are evicted from memory
- **AND** evicted entries remain available in persistent disk cache

#### Scenario: Memory cache cleared on app lifecycle events

- **WHEN** the app is terminated or backgrounded
- **THEN** the in-memory cache is cleared
- **AND** the persistent disk cache remains intact
- **AND** memory cache is rebuilt on app restart as requests are made

### Requirement: Secure Cache for Sensitive Data

The library SHALL provide options to exclude sensitive data from caching.

#### Scenario: No-cache for authenticated requests

- **WHEN** a request includes an Authorization header
- **AND** sensitive data caching is disabled
- **THEN** the response is not cached
- **AND** the request always hits the network

#### Scenario: Default cache key generation

- **WHEN** a request is made without custom cache key configuration
- **THEN** the cache key includes the HTTP method and full URL
- **AND** all query parameters are included in the cache key
- **AND** request headers are excluded from the cache key
- **AND** requests with identical method and URL share the same cache entry

#### Scenario: Query parameters in cache keys

- **WHEN** two GET requests differ only in query parameters
- **THEN** they are treated as separate cache entries
- **AND** each parameter combination has its own cached response

#### Scenario: Cache key customization

- **WHEN** a developer provides a custom cache key function
- **THEN** the custom function is used to generate cache keys
- **AND** developers can exclude specific parameters (e.g., auth tokens) from cache keys

### Requirement: Cache Error Handling

The library SHALL handle cache storage failures gracefully without disrupting request processing.

#### Scenario: Cache write failure is transparent

- **WHEN** writing to the cache fails due to disk errors
- **THEN** the response is still returned to the caller
- **AND** the error is logged for debugging
- **AND** the request is not retried
- **AND** subsequent requests attempt to use cache normally

#### Scenario: Cache read failure falls back to network

- **WHEN** reading from the cache fails due to corrupted data
- **THEN** the corrupted cache entry is deleted
- **AND** a fresh network request is made
- **AND** the error is logged for debugging
- **AND** the fresh response is cached if successful

#### Scenario: Corrupted cache detected and cleaned

- **WHEN** the cache is initialized at app startup
- **AND** corrupted cache entries are detected
- **THEN** corrupted entries are removed
- **AND** valid cache entries are preserved
- **AND** the cleanup is logged

#### Scenario: Disk space exhausted

- **WHEN** cache write fails due to insufficient disk space
- **THEN** the cache evicts entries using LRU policy
- **AND** the write is retried once after eviction
- **AND** if retry fails, the error is logged and request proceeds

### Requirement: Dio Cache Interceptor Integration

The library SHALL integrate `dio_cache_interceptor` for cache implementation.

#### Scenario: Cache interceptor configuration

- **WHEN** caching is enabled
- **THEN** `dio_cache_interceptor` is added to the interceptor chain
- **AND** cache options are configured based on `CacheConfig`
- **AND** cache store is initialized with persistent storage
