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
- **AND** oldest entries are evicted when the limit is reached

```dart
final dio = AcdcClientBuilder()
  .withCache(CacheConfig(
    maxSize: 50 * 1024 * 1024, // 50 MB
  ))
  .build();
```

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

### Requirement: Secure Cache for Sensitive Data

The library SHALL provide options to exclude sensitive data from caching.

#### Scenario: No-cache for authenticated requests

- **WHEN** a request includes an Authorization header
- **AND** sensitive data caching is disabled
- **THEN** the response is not cached
- **AND** the request always hits the network

#### Scenario: Cache key customization

- **WHEN** a developer provides a custom cache key function
- **THEN** the custom function is used to generate cache keys
- **AND** developers can exclude specific parameters (e.g., auth tokens) from cache keys

### Requirement: Dio Cache Interceptor Integration

The library SHALL integrate `dio_cache_interceptor` for cache implementation.

#### Scenario: Cache interceptor configuration

- **WHEN** caching is enabled
- **THEN** `dio_cache_interceptor` is added to the interceptor chain
- **AND** cache options are configured based on `CacheConfig`
- **AND** cache store is initialized with persistent storage
