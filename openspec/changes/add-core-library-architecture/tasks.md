# Implementation Tasks

## 1. Project Setup

- [ ] 1.1 Create `pubspec.yaml` with package metadata and dependencies
- [ ] 1.2 Create `analysis_options.yaml` with strict linting rules
- [ ] 1.3 Create directory structure (`lib/`, `lib/src/`, `test/`)
- [ ] 1.4 Create `.gitignore` for Dart/Flutter projects
- [ ] 1.5 Create `README.md` with basic project description
- [ ] 1.6 Create `LICENSE` file (choose license: MIT, Apache 2.0, etc.)
- [ ] 1.7 Create `CHANGELOG.md` for version tracking

## 2. Core Types and Interfaces

- [ ] 2.1 Define `TokenProvider` interface in `lib/src/auth/token_provider.dart`
  - [ ] 2.1.1 Add `getAccessToken()` method
  - [ ] 2.1.2 Add `getRefreshToken()` method
  - [ ] 2.1.3 Add `getAccessTokenExpiry()` method (UTC)
  - [ ] 2.1.4 Add `getRefreshTokenExpiry()` method (UTC)
  - [ ] 2.1.5 Add `setTokens()` method with expiry parameters
  - [ ] 2.1.6 Add `clearTokens()` method
- [ ] 2.2 Define `TokenRefreshResult` class in `lib/src/auth/token_refresh_result.dart`
  - [ ] 2.2.1 Add required `accessToken` field
  - [ ] 2.2.2 Add optional `refreshToken` field (for rotation)
  - [ ] 2.2.3 Add optional `accessExpiry` and `refreshExpiry` fields
- [ ] 2.3 Define custom exception hierarchy in `lib/src/exceptions/`
  - [ ] 2.3.1 `AcdcException` base class (extends DioException)
  - [ ] 2.3.2 `AcdcNetworkException` with `NetworkErrorType` enum
  - [ ] 2.3.3 `AcdcAuthException`
  - [ ] 2.3.4 `AcdcServerException`
  - [ ] 2.3.5 `AcdcClientException`
  - [ ] 2.3.6 `AcdcCacheException` with `CacheOperation` enum
  - [ ] 2.3.7 Add `toMap()` method for structured logging
  - [ ] 2.3.8 Add response body truncation (1KB limit)
  - [ ] 2.3.9 Add URL redaction for sensitive parameters
- [ ] 2.4 Define `LogLevel` enum in `lib/src/logging/log_level.dart`
  - [ ] 2.4.1 Add values: debug, info, warning, error, none
- [ ] 2.5 Define `AcdcLogger` typedef in `lib/src/logging/acdc_logger.dart`
- [ ] 2.6 Write unit tests for exception types

## 3. Error Handling Interceptor

- [ ] 3.1 Create `ErrorInterceptor` class in `lib/src/interceptors/error_interceptor.dart`
- [ ] 3.2 Implement HTTP status code to exception mapping
  - [ ] 3.2.1 Map 401/403 to `AcdcAuthException`
  - [ ] 3.2.2 Map 4xx (others) to `AcdcClientException`
  - [ ] 3.2.3 Map 5xx to `AcdcServerException`
  - [ ] 3.2.4 Handle 429 with Retry-After header parsing
- [ ] 3.3 Implement network error handling
  - [ ] 3.3.1 Map timeouts to `AcdcNetworkException`
  - [ ] 3.3.2 Map connection errors to `AcdcNetworkException`
  - [ ] 3.3.3 Include timeout type differentiation
- [ ] 3.4 Add developer-friendly error message generation
- [ ] 3.5 Implement response body truncation logic
- [ ] 3.6 Implement URL redaction for sensitive parameters
- [ ] 3.7 Handle edge cases (malformed responses, redirects)
- [ ] 3.8 Ensure error interceptor runs AFTER auth interceptor attempts refresh
- [ ] 3.9 Write unit tests for error interceptor
- [ ] 3.10 Write tests for 401 bypass when auth interceptor handles it

## 4. Authentication Components

- [ ] 4.1 Create `AuthInterceptor` class in `lib/src/interceptors/auth_interceptor.dart`
  - [ ] 4.1.1 Implement Bearer token injection in request headers
  - [ ] 4.1.2 Handle existing Authorization header preservation
  - [ ] 4.1.3 Implement token expiry validation before requests
- [ ] 4.2 Implement proactive token refresh
  - [ ] 4.2.1 Check `getAccessTokenExpiry()` before requests
  - [ ] 4.2.2 Trigger refresh when within threshold (default: 60s, configurable)
  - [ ] 4.2.3 Queue current request until refresh completes
  - [ ] 4.2.4 Handle refresh failures (network vs auth errors)
  - [ ] 4.2.5 Fall back to reactive refresh if expiry unavailable
- [ ] 4.3 Implement reactive token refresh on 401
  - [ ] 4.3.1 Detect 401 responses
  - [ ] 4.3.2 Check for available refresh token
  - [ ] 4.3.3 Trigger refresh and retry original request
  - [ ] 4.3.4 Handle 401 without refresh token
  - [ ] 4.3.5 Implement single retry limit (prevent infinite loops)
  - [ ] 4.3.6 Clear tokens on repeated 401 after refresh
- [ ] 4.4 Implement concurrent request queuing during refresh
  - [ ] 4.4.1 Detect simultaneous token expiry across requests
  - [ ] 4.4.2 Queue subsequent requests while first refreshes
  - [ ] 4.4.3 Resume all queued requests with new token on success
  - [ ] 4.4.4 Fail all queued requests on refresh failure
  - [ ] 4.4.5 Implement refresh queue timeout (default: 10s)
- [ ] 4.5 Implement token refresh endpoint support
  - [ ] 4.5.1 Create OAuth 2.1 refresh request (POST with form-urlencoded)
  - [ ] 4.5.2 Include grant_type, refresh_token, client_id (NO client_secret)
  - [ ] 4.5.3 Parse refresh response (access_token, refresh_token, expires_in)
  - [ ] 4.5.4 Use server Date header for clock skew handling
  - [ ] 4.5.5 Call `setTokens()` with new tokens
  - [ ] 4.5.6 Support custom refresh function via callback
- [ ] 4.6 Implement token refresh error handling
  - [ ] 4.6.1 Parse OAuth error responses (invalid_grant, etc.)
  - [ ] 4.6.2 Map OAuth errors to specific messages
  - [ ] 4.6.3 Clear tokens on auth errors (invalid_grant)
  - [ ] 4.6.4 Preserve tokens on network/server errors
  - [ ] 4.6.5 Implement exponential backoff for 5xx errors
- [ ] 4.7 Implement token refresh isolation
  - [ ] 4.7.1 Create separate minimal Dio instance for refresh requests
  - [ ] 4.7.2 Bypass auth, cache, and custom interceptors
  - [ ] 4.7.3 Include only error interceptor and minimal logging
  - [ ] 4.7.4 Redact refresh_token and access_token in logs
- [ ] 4.8 Handle TokenProvider exceptions
  - [ ] 4.8.1 Catch `getAccessToken()` exceptions → proceed without auth
  - [ ] 4.8.2 Catch `getRefreshToken()` exceptions → fail with clear error
  - [ ] 4.8.3 Catch `setTokens()` exceptions → fail refresh, log error
  - [ ] 4.8.4 Catch `clearTokens()` exceptions → log warning, continue
  - [ ] 4.8.5 Ensure exceptions never crash the app
- [ ] 4.9 Handle logout during active refresh
  - [ ] 4.9.1 Detect logout call while refresh in progress
  - [ ] 4.9.2 Cancel in-progress refresh request
  - [ ] 4.9.3 Fail queued requests with logout indication
  - [ ] 4.9.4 Proceed with normal logout flow
- [ ] 4.10 Create `AcdcAuthManager` class in `lib/src/auth/acdc_auth_manager.dart`
  - [ ] 4.10.1 Implement `logout()` method with token revocation
  - [ ] 4.10.2 Implement `refreshNow()` method for forced refresh
  - [ ] 4.10.3 Implement `clearCache()` method
  - [ ] 4.10.4 Store reference to cache and auth interceptor
- [ ] 4.11 Create `AcdcAuth` Dart extension on Dio
  - [ ] 4.11.1 Add `auth` getter returning `AcdcAuthManager`
  - [ ] 4.11.2 Store manager reference in Dio options
  - [ ] 4.11.3 Handle case when auth is not configured
- [ ] 4.12 Implement token revocation for logout
  - [ ] 4.12.1 POST to revocation endpoint with token and token_type_hint
  - [ ] 4.12.2 Revoke refresh token first, then access token
  - [ ] 4.12.3 Handle revocation failures gracefully (best-effort)
  - [ ] 4.12.4 Always clear tokens locally regardless of revocation success
- [ ] 4.13 Support token rotation
  - [ ] 4.13.1 Update both tokens when new refresh_token in response
  - [ ] 4.13.2 Retain old refresh token if not rotated
- [ ] 4.14 Handle expired refresh tokens
  - [ ] 4.14.1 Check `getRefreshTokenExpiry()` before refresh
  - [ ] 4.14.2 Clear tokens and fail if refresh token expired
- [ ] 4.15 Write unit tests for auth interceptor
- [ ] 4.16 Write integration tests for token refresh flow
- [ ] 4.17 Write tests for concurrent request queuing
- [ ] 4.18 Write tests for logout during refresh

## 5. Logging Interceptor

- [ ] 5.1 Create `LoggingInterceptor` class in `lib/src/interceptors/logging_interceptor.dart`
- [ ] 5.2 Integrate `pretty_dio_logger` for debug mode
- [ ] 5.3 Implement environment-aware logging
  - [ ] 5.3.1 Detect `kDebugMode` for default behavior
  - [ ] 5.3.2 Support explicit `LogLevel` override
  - [ ] 5.3.3 Pretty-print in debug, minimal in release
- [ ] 5.4 Implement sensitive data redaction
  - [ ] 5.4.1 Redact Authorization header values
  - [ ] 5.4.2 Redact password, token, secret fields (case-insensitive)
  - [ ] 5.4.3 Support custom sensitive field patterns
  - [ ] 5.4.4 Apply redaction in release mode and for refresh requests
- [ ] 5.5 Implement request duration tracking
  - [ ] 5.5.1 Track and log request duration
  - [ ] 5.5.2 Warn on slow requests (default: 3s, configurable)
- [ ] 5.6 Implement structured logging metadata
  - [ ] 5.6.1 Include timestamp, method, URL, status code, duration
  - [ ] 5.6.2 Support request ID if available
  - [ ] 5.6.3 Format for both human and machine readability
- [ ] 5.7 Support custom logger
  - [ ] 5.7.1 Accept custom `AcdcLogger` function
  - [ ] 5.7.2 Pass message, level, and metadata to custom logger
  - [ ] 5.7.3 Ensure synchronous interface with async dispatch
- [ ] 5.8 Implement comprehensive error logging
  - [ ] 5.8.1 Log network failures with error type
  - [ ] 5.8.2 Log HTTP errors (4xx as warning, 5xx as error)
  - [ ] 5.8.3 Log retry attempts
  - [ ] 5.8.4 Log request cancellations
  - [ ] 5.8.5 Log timeout type differentiation
  - [ ] 5.8.6 Log SSL/certificate errors
  - [ ] 5.8.7 Log response parsing errors
- [ ] 5.9 Implement cross-interceptor logging
  - [ ] 5.9.1 Log cache hits/misses
  - [ ] 5.9.2 Log token refresh events (redacted)
  - [ ] 5.9.3 Log request modifications by interceptors
  - [ ] 5.9.4 Log cache writes
  - [ ] 5.9.5 Log HTTP redirects
- [ ] 5.10 Implement logging error resilience
  - [ ] 5.10.1 Catch and ignore logger exceptions
  - [ ] 5.10.2 Fallback to print() in debug mode on logger failure
  - [ ] 5.10.3 Prevent circular logging dependencies
  - [ ] 5.10.4 Throttle slow logging operations
  - [ ] 5.10.5 Ensure zero user-visible impact on failures
- [ ] 5.11 Implement request validation logging
  - [ ] 5.11.1 Log validation errors before request fails
  - [ ] 5.11.2 Warn on large payloads (default: 1MB, configurable)
- [ ] 5.12 Write unit tests for logging interceptor
- [ ] 5.13 Write tests for custom logger integration
- [ ] 5.14 Write tests for sensitive data redaction

## 6. Cache Components

- [ ] 6.1 Create `CacheConfig` class in `lib/src/cache/cache_config.dart`
  - [ ] 6.1.1 Add TTL configuration (default: 1 hour)
  - [ ] 6.1.2 Add max size configuration (default: 10 MB)
  - [ ] 6.1.3 Add cacheAuthenticatedRequests flag (default: true)
  - [ ] 6.1.4 Add encrypted flag for encrypted cache
  - [ ] 6.1.5 Add requireEncryption flag
  - [ ] 6.1.6 Add inMemory flag for in-memory layer
  - [ ] 6.1.7 Add inMemoryMaxSize configuration
  - [ ] 6.1.8 Add staleWhileRevalidate flag
  - [ ] 6.1.9 Add staleIfError flag
  - [ ] 6.1.10 Add userIdProvider callback for non-JWT auth
- [ ] 6.2 Integrate `dio_cache_interceptor`
  - [ ] 6.2.1 Configure with sensible defaults
  - [ ] 6.2.2 Apply user-provided CacheConfig options
  - [ ] 6.2.3 Set up persistent disk storage
  - [ ] 6.2.4 Exclude cache directory from backups
- [ ] 6.3 Implement HTTP cache header support
  - [ ] 6.3.1 Respect Cache-Control headers (max-age, no-cache, no-store)
  - [ ] 6.3.2 Implement ETag-based conditional requests
  - [ ] 6.3.3 Handle 304 Not Modified responses
  - [ ] 6.3.4 Implement Last-Modified support
- [ ] 6.4 Implement HTTP method-based caching
  - [ ] 6.4.1 Cache only GET requests by default
  - [ ] 6.4.2 Allow HEAD requests to use GET cache
  - [ ] 6.4.3 Never cache POST/PUT/PATCH/DELETE
  - [ ] 6.4.4 Invalidate cache on successful mutations
- [ ] 6.5 Implement user-based cache isolation
  - [ ] 6.5.1 Extract user ID from JWT access token (sub, user_id, uid claims)
  - [ ] 6.5.2 Include user ID in cache keys for authenticated requests
  - [ ] 6.5.3 Separate cache entries per user
  - [ ] 6.5.4 Handle JWT decoding failures gracefully
  - [ ] 6.5.5 Support custom userIdProvider for non-JWT tokens
  - [ ] 6.5.6 Clear cache on user change detection
  - [ ] 6.5.7 Ensure cache isolation on shared devices
- [ ] 6.6 Implement encrypted cache storage
  - [ ] 6.6.1 Encrypt responses before writing to disk
  - [ ] 6.6.2 Decrypt responses on cache reads
  - [ ] 6.6.3 Store encryption keys in platform secure storage
  - [ ] 6.6.4 Handle encryption key rotation
  - [ ] 6.6.5 Fallback to unencrypted if encryption unavailable
  - [ ] 6.6.6 Disable caching if requireEncryption=true and encryption fails
- [ ] 6.7 Implement in-memory cache layer
  - [ ] 6.7.1 Add memory cache before disk cache
  - [ ] 6.7.2 Implement LRU eviction for memory cache
  - [ ] 6.7.3 Clear memory cache on app lifecycle events
  - [ ] 6.7.4 Keep disk cache intact on memory cache clear
- [ ] 6.8 Implement stale-while-revalidate
  - [ ] 6.8.1 Serve stale cache immediately when enabled
  - [ ] 6.8.2 Trigger background refresh request
  - [ ] 6.8.3 Update cache with fresh response
- [ ] 6.9 Implement offline network handling
  - [ ] 6.9.1 Serve stale cache on network unavailability
  - [ ] 6.9.2 Add X-ACDC-From-Cache header
  - [ ] 6.9.3 Set response.extra['fromOfflineCache'] flag
  - [ ] 6.9.4 Throw AcdcNetworkException if no cache available
- [ ] 6.10 Implement cache invalidation
  - [ ] 6.10.1 Add clearCache() to AcdcAuthManager
  - [ ] 6.10.2 Add clearCacheForUrl() method
  - [ ] 6.10.3 Auto-clear cache on logout
  - [ ] 6.10.4 Auto-clear on app version change
  - [ ] 6.10.5 Handle incomplete logout states on startup
- [ ] 6.11 Implement cache error handling
  - [ ] 6.11.1 Handle cache initialization failures → disable caching
  - [ ] 6.11.2 Handle write failures → log and continue
  - [ ] 6.11.3 Handle read failures → delete corrupt entry, fetch fresh
  - [ ] 6.11.4 Clean corrupted entries on startup
  - [ ] 6.11.5 Handle disk space exhaustion with LRU eviction
- [ ] 6.12 Implement LRU eviction policy
  - [ ] 6.12.1 Update access time on cache reads
  - [ ] 6.12.2 Evict least recently used on size limit
- [ ] 6.13 Support custom cache key functions
  - [ ] 6.13.1 Allow developers to provide cache key generator
  - [ ] 6.13.2 Include method, URL, user ID in default key
- [ ] 6.14 Write unit tests for cache configuration
- [ ] 6.15 Write integration tests for user isolation
- [ ] 6.16 Write tests for encrypted cache
- [ ] 6.17 Write tests for offline handling
- [ ] 6.18 Write tests for cache initialization failures

## 7. HTTP Client Builder

- [ ] 7.1 Create `AcdcClientBuilder` class in `lib/src/builder/acdc_client_builder.dart`
  - [ ] 7.1.1 Implement immutable builder pattern
  - [ ] 7.1.2 Each configuration method returns new builder instance
- [ ] 7.2 Implement fluent builder methods:
  - [ ] 7.2.1 `withBaseUrl(String url)`
  - [ ] 7.2.2 `withTimeout(Duration timeout)`
  - [ ] 7.2.3 `withTokenProvider(TokenProvider provider)`
  - [ ] 7.2.4 `withTokenRefreshEndpoint({required String url, required String clientId})`
  - [ ] 7.2.5 `withCustomTokenRefresh(Future<TokenRefreshResult> Function(String) refreshFn)`
  - [ ] 7.2.6 `withTokenRevocationEndpoint(String url)`
  - [ ] 7.2.7 `withTokenRefreshThreshold(Duration threshold)`
  - [ ] 7.2.8 `withLogLevel(LogLevel level)`
  - [ ] 7.2.9 `withLogger(AcdcLogger logger)`
  - [ ] 7.2.10 `withSensitiveFields(List<dynamic> fields)`
  - [ ] 7.2.11 `withSlowRequestThreshold(Duration threshold)`
  - [ ] 7.2.12 `withLargePayloadThreshold(int bytes)`
  - [ ] 7.2.13 `withCache(CacheConfig config)`
  - [ ] 7.2.14 `disableCache()`
  - [ ] 7.2.15 `withInterceptor(Interceptor interceptor)`
- [ ] 7.3 Implement `build()` method
  - [ ] 7.3.1 Create new Dio instance each time
  - [ ] 7.3.2 Allow builder reuse for multiple instances
  - [ ] 7.3.3 Set base URL if configured
  - [ ] 7.3.4 Set default timeouts (30s for connect/send/receive)
  - [ ] 7.3.5 Configure interceptor chain in correct order
  - [ ] 7.3.6 Return standard Dio instance (not wrapper)
- [ ] 7.4 Configure interceptor chain with correct order
  - [ ] 7.4.1 Request phase: Logging → Auth → Cache
  - [ ] 7.4.2 Response phase: Cache → Auth → Error → Logging
  - [ ] 7.4.3 Append custom interceptors at end
- [ ] 7.5 Implement builder validation
  - [ ] 7.5.1 Validate timeout is positive
  - [ ] 7.5.2 Validate base URL format
  - [ ] 7.5.3 Reject null required parameters
  - [ ] 7.5.4 Last configuration wins on conflicts
- [ ] 7.6 Set up AcdcAuthManager
  - [ ] 7.6.1 Create manager instance if auth configured
  - [ ] 7.6.2 Store in Dio options for extension access
  - [ ] 7.6.3 Provide informative errors if auth not configured
- [ ] 7.7 Write unit tests for builder
- [ ] 7.8 Write tests for builder immutability
- [ ] 7.9 Write tests for build() reusability
- [ ] 7.10 Write integration tests for complete client

## 8. Public API

- [ ] 8.1 Create `lib/dart_acdc.dart` with public exports
- [ ] 8.2 Export builder class
- [ ] 8.3 Export exception classes
- [ ] 8.4 Export TokenProvider interface
- [ ] 8.5 Export TokenRefreshResult class
- [ ] 8.6 Export AcdcAuthManager and extension
- [ ] 8.7 Export CacheConfig class
- [ ] 8.8 Export LogLevel enum
- [ ] 8.9 Export AcdcLogger typedef
- [ ] 8.10 Keep internal implementation in `lib/src/` private
- [ ] 8.11 Add dartdoc comments to all public APIs

## 9. Documentation

- [ ] 9.1 Write comprehensive README.md with:
  - [ ] 9.1.1 Installation instructions
  - [ ] 9.1.2 Quick start example
  - [ ] 9.1.3 Zero-config usage example
  - [ ] 9.1.4 Configuration examples (auth, logging, caching)
  - [ ] 9.1.5 OpenAPI integration example
  - [ ] 9.1.6 TokenProvider implementation examples (iOS Keychain, Android Keystore)
  - [ ] 9.1.7 Custom logger example
  - [ ] 9.1.8 Logout example
- [ ] 9.2 Add dartdoc comments to all public classes and methods
- [ ] 9.3 Create `example/` directory with working example
- [ ] 9.4 Document supported Dart/Flutter versions
- [ ] 9.5 Document security best practices
  - [ ] 9.5.1 Secure token storage
  - [ ] 9.5.2 OAuth 2.1 public client requirements
  - [ ] 9.5.3 Cache encryption recommendations

## 10. Testing

- [ ] 10.1 Unit tests for all components
  - [ ] 10.1.1 Exception types
  - [ ] 10.1.2 Error interceptor
  - [ ] 10.1.3 Auth interceptor
  - [ ] 10.1.4 Logging interceptor
  - [ ] 10.1.5 Cache configuration
  - [ ] 10.1.6 Builder
- [ ] 10.2 Integration tests
  - [ ] 10.2.1 Complete client with all features enabled
  - [ ] 10.2.2 Token refresh flow (proactive and reactive)
  - [ ] 10.2.3 Concurrent request queuing
  - [ ] 10.2.4 Logout during refresh
  - [ ] 10.2.5 TokenProvider exception handling
  - [ ] 10.2.6 Cache initialization failure
  - [ ] 10.2.7 User-based cache isolation
  - [ ] 10.2.8 Offline caching
  - [ ] 10.2.9 Custom logger integration
  - [ ] 10.2.10 Builder immutability and reusability
- [ ] 10.3 Test with openapi-generated client (manual integration test)
- [ ] 10.4 Run `dart analyze` with zero issues
- [ ] 10.5 Run `dart format` on all files
- [ ] 10.6 Achieve 80%+ code coverage
- [ ] 10.7 Test on both iOS and Android platforms

## 11. Example Project

- [ ] 11.1 Create `example/` directory
- [ ] 11.2 Create example Flutter app using dart_acdc
- [ ] 11.3 Include OpenAPI spec (e.g., JSONPlaceholder API)
- [ ] 11.4 Generate client using openapi-generator
- [ ] 11.5 Demonstrate zero-config usage
- [ ] 11.6 Demonstrate custom configuration
- [ ] 11.7 Demonstrate authentication flow
- [ ] 11.8 Demonstrate token refresh
- [ ] 11.9 Demonstrate logout
- [ ] 11.10 Demonstrate offline caching
- [ ] 11.11 Add example README with instructions

## 12. Package Publishing Preparation

- [ ] 12.1 Verify `pubspec.yaml` metadata (description, homepage, repository)
- [ ] 12.2 Run `dart pub publish --dry-run`
- [ ] 12.3 Fix any pub.dev publishing warnings
- [ ] 12.4 Create initial git tag `v0.1.0`

## Dependencies

**Parallel tracks:**
- Tasks 3, 4, 5, 6 (Interceptors and Cache) can be done in parallel
- Task 9 (Documentation) can be done alongside implementation

**Sequential dependencies:**
- Task 2 (Core Types) must complete before tasks 3-6
- Task 7 (Builder) depends on tasks 2-6
- Task 8 (Public API) depends on task 7
- Task 10 (Testing) should be done continuously, finalized at end
- Task 11 (Example) depends on task 8
- Task 12 (Publishing prep) depends on all previous tasks

## Validation

After completing all tasks:

1. `dart analyze` returns zero issues
2. `dart test` passes all tests with 80%+ coverage
3. `dart format` shows no changes needed
4. Example app runs successfully on iOS and Android simulators
5. OpenAPI integration example works end-to-end
6. `dart pub publish --dry-run` succeeds with no warnings
7. All edge cases from specs are tested (TokenProvider exceptions, logout during refresh, cache failures, etc.)
