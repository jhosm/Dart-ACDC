# caching Specification

## Purpose
TBD - created by archiving change add-core-library-architecture. Update Purpose after archive.
## Requirements
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
- **AND** authenticated requests ARE cached by default with user-based isolation
- **AND** only GET requests are cached by default

#### Scenario: Cacheable response criteria

- **WHEN** evaluating if a response is cacheable with default settings
- **THEN** the response is cacheable if ALL of the following are true:
  - HTTP method is GET or HEAD
  - Response status code is 200
  - Cache-Control header does not include `no-cache` or `no-store`
  - If request includes Authorization header, user ID can be extracted from JWT
  - Response is not explicitly marked as uncacheable
- **AND** responses not meeting these criteria are never cached

#### Scenario: Cache opt-out

- **WHEN** a developer calls `AcdcClientBuilder().disableCache()`
- **THEN** no cache interceptor is added
- **AND** all requests bypass caching

#### Scenario: Cache TTL and token expiry interaction

- **WHEN** cache TTL is configured
- **THEN** the library recommends cache TTL ≤ access token TTL for optimal token refresh behavior
- **AND** cached responses may be served even if the access token has expired
- **AND** this is safe because cached data was fetched when the user was authenticated
- **AND** the next non-cached request will trigger token refresh if the token has expired
- **AND** developers can configure shorter cache TTL for frequently changing data

### Requirement: Cache Policy Configuration

The library SHALL allow developers to configure cache behavior with custom policies.

```dart
// Comprehensive cache configuration example
final dio = AcdcClientBuilder()
  .withCache(CacheConfig(
    // Basic settings
    ttl: Duration(hours: 24),
    maxSize: 50 * 1024 * 1024, // 50 MB

    // Advanced features
    inMemory: true,
    inMemoryMaxSize: 5 * 1024 * 1024,
    staleWhileRevalidate: true,
    staleIfError: true,

    // Security
    cacheAuthenticatedRequests: true,  // Default: true (with user-based isolation)
    userIdProvider: () async => await myAuthService.getUserId(),  // Optional: for non-JWT tokens
    encrypted: true,
    requireEncryption: false,
  ))
  .build();
```

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

The library SHALL provide methods to clear cached responses when needed via the auth extension.

#### Scenario: Clear all cache

- **WHEN** a developer calls `dio.auth.clearCache()`
- **THEN** all cached responses are removed
- **AND** subsequent requests hit the network

#### Scenario: Clear specific URL cache

- **WHEN** a developer calls `dio.auth.clearCacheForUrl(url)`
- **THEN** cached responses for that URL are removed
- **AND** other cached responses remain intact

#### Scenario: Automatic cache clear on logout

- **WHEN** the user logs out via the authentication system
- **THEN** all cached responses are automatically cleared
- **AND** the in-memory cache is cleared
- **AND** the persistent disk cache is cleared
- **AND** subsequent login starts with a fresh cache

#### Scenario: Cache cleanup after failed logout

- **WHEN** logout failed or app crashed during logout
- **AND** the app restarts
- **THEN** the library detects the incomplete logout state
- **AND** all cached responses are cleared automatically on startup
- **AND** this prevents stale authenticated data from persisting

#### Scenario: Cache clear on app version change

- **WHEN** the app version changes (detected on startup)
- **THEN** all cached responses are automatically cleared
- **AND** the new version starts with a fresh cache
- **AND** this prevents schema incompatibilities from cached data

### Requirement: Stale-While-Revalidate Support

The library SHALL support serving stale cache data while revalidating in the background.

```dart
final dio = AcdcClientBuilder()
  .withCache(CacheConfig(
    staleWhileRevalidate: true,  // Enable stale-while-revalidate
    staleIfError: true,  // Serve stale on network error
  ))
  .build();
```

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
- **AND** response headers include `X-ACDC-From-Cache: offline`
- **AND** developers can check `response.extra['fromOfflineCache'] == true`
- **AND** the cache timestamp is available in response metadata

#### Scenario: Network unavailable with no cache

- **WHEN** a request fails due to network unavailability
- **AND** no cached response exists
- **THEN** an AcdcNetworkException is thrown
- **AND** the exception message indicates offline state
- **AND** the exception type is specifically network unavailability

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

### Requirement: Encrypted Cache Storage (Optional)

The library SHALL provide optional encryption for cached responses to protect sensitive data at rest.

#### Scenario: Enable encrypted cache

- **WHEN** a developer enables encrypted caching
- **THEN** cached responses are encrypted before writing to disk
- **AND** responses are automatically decrypted on cache reads
- **AND** encryption keys are stored in platform secure storage (iOS Keychain, Android Keystore)
- **AND** cache remains functional if encryption is unavailable

```dart
final dio = AcdcClientBuilder()
  .withCache(CacheConfig(
    encrypted: true,  // Enables encryption at rest
  ))
  .build();
```

#### Scenario: Encryption key rotation

- **WHEN** the encryption key is rotated (e.g., after user re-authentication)
- **THEN** existing cache entries are invalidated
- **AND** new cache entries use the new encryption key
- **AND** old encrypted entries are cleared

#### Scenario: Encryption unavailable fallback

- **WHEN** encrypted caching is enabled
- **AND** platform secure storage is unavailable
- **THEN** a warning is logged
- **AND** caching continues without encryption
- **OR** caching is disabled entirely if `requireEncryption: true` is set

### Requirement: In-Memory Cache Layer

The library SHALL provide an optional in-memory cache layer for fast access to frequently requested data.

```dart
final dio = AcdcClientBuilder()
  .withCache(CacheConfig(
    inMemory: true,  // Enable in-memory cache layer
    inMemoryMaxSize: 5 * 1024 * 1024,  // 5 MB memory cache
  ))
  .build();
```

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

The library SHALL cache authenticated requests by default using user-based cache isolation to provide both security and performance.

#### Scenario: Unauthenticated requests cached normally

- **WHEN** a request does NOT include an Authorization header
- **THEN** the response is cached normally (if other criteria are met)
- **AND** the cache key does NOT include a user ID
- **AND** all users share the same cache for unauthenticated endpoints
- **AND** this is safe because unauthenticated endpoints return public data

#### Scenario: Authenticated requests cached with user isolation

- **WHEN** a request includes an Authorization header with a JWT access token
- **THEN** the response IS cached by default
- **AND** the user ID (from JWT claims `sub` or `user_id`) is included in the cache key
- **AND** each user has isolated cache entries
- **AND** cache persists across token refreshes (same user, new token)
- **AND** this prevents cross-user cache contamination while enabling performance

#### Scenario: User ID extraction from JWT

- **WHEN** processing an authenticated request for caching
- **THEN** the library attempts to decode the JWT access token (without signature verification)
- **AND** user ID is obtained from standard claims: `sub`, `user_id`, or `uid` (in that order)
- **AND** if JWT decoding fails (malformed token), the request is not cached
- **AND** if JWT is valid but user ID claims are missing, the request is not cached
- **AND** extraction failures are logged with the specific reason
- **AND** failed requests proceed to the network normally (caching failure does not block requests)

#### Scenario: Cache cleared on user change

- **WHEN** the user ID from the current token differs from the previous session
- **THEN** all cached responses are automatically cleared
- **AND** the new user starts with a fresh cache
- **AND** this prevents data leakage between different users on the same device

#### Scenario: Multiple users on same device

- **WHEN** User A logs in and uses the app
- **AND** User A logs out
- **AND** User B logs in on the same device
- **THEN** all of User A's cached responses are cleared (due to user change detection)
- **AND** User B starts with an empty cache
- **AND** User B cannot access any of User A's cached data
- **AND** this ensures complete data isolation on shared devices

#### Scenario: Opt-out of authenticated request caching

- **WHEN** a developer disables caching of authenticated requests
- **THEN** requests with Authorization headers are never cached
- **AND** all authenticated requests hit the network

```dart
final dio = AcdcClientBuilder()
  .withCache(CacheConfig(
    cacheAuthenticatedRequests: false,  // Disable if needed
  ))
  .build();
```

#### Scenario: Non-JWT token fallback

- **WHEN** the Authorization header contains a non-JWT token (e.g., opaque token)
- **AND** user ID cannot be extracted
- **THEN** the request is NOT cached
- **AND** a warning is logged suggesting to provide a userIdProvider
- **AND** developer can provide a custom user ID provider for non-JWT auth schemes

```dart
final dio = AcdcClientBuilder()
  .withCache(CacheConfig(
    userIdProvider: () async => await myAuthService.getCurrentUserId(),
  ))
  .build();
```

#### Scenario: Cache isolation example

- **WHEN** User A (ID: "user-123") requests `/api/profile`
- **AND** the response is cached with cache key: `GET:/api/profile:user-123`
- **AND** User A's access token refreshes (new token, same user ID)
- **THEN** subsequent requests by User A still use the cached response
- **AND** the cache persists across token refreshes
- **WHEN** User B (ID: "user-456") requests `/api/profile` on the same device
- **THEN** User B gets a separate cache entry with key: `GET:/api/profile:user-456`
- **AND** User A and User B never see each other's cached data

#### Scenario: Default cache key generation

- **WHEN** a request is made without custom cache key configuration
- **THEN** the cache key includes the HTTP method and full URL
- **AND** all query parameters are included in the cache key
- **AND** request headers are excluded from the cache key
- **AND** if the request includes an Authorization header, the user ID is included in the cache key
- **AND** requests from the same user with identical method and URL share the same cache entry
- **AND** requests from different users with identical method and URL have separate cache entries

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

#### Scenario: Cache initialization failure at startup

- **WHEN** the cache storage cannot be initialized at app startup
- **AND** the failure is due to disk permissions, corrupted state, or missing dependencies
- **THEN** the error is logged with details
- **AND** caching is automatically disabled for the session
- **AND** all requests proceed normally without caching (direct network calls)
- **AND** no cache reads or writes are attempted
- **AND** the application does not crash or show errors to users
- **AND** on next app restart, cache initialization is retried

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

#### Scenario: Cache and auth interceptor interaction

- **WHEN** caching is enabled alongside authentication
- **THEN** the cache interceptor is placed after the auth interceptor in the request phase
- **AND** access tokens are injected before the cache is checked
- **AND** cache hits return immediately without reaching the network
- **AND** cache hits bypass token refresh logic (token refresh only happens on network requests)
- **AND** this is expected behavior - cached data validity is independent of current token validity
- **AND** expired tokens are refreshed on the next cache miss or non-cacheable request

