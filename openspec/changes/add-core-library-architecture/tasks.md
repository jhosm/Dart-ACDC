# Implementation Tasks

## Progress Overview

**Overall Completion: 44.64%** (25 of 56 beads issues completed)

### Status Legend

- ✅ Complete
- 🚧 In Progress
- ⏳ Blocked/Pending

### Section Status

1. ✅ Project Setup - Complete
2. ✅ Core Types and Interfaces - Complete
3. ✅ Error Handling Interceptor - Complete
4. ✅ Authentication Components - Complete
5. ⏳ Logging Interceptor - Pending (blocked by dependencies)
6. ⏳ Cache Components - Pending (blocked by dependencies)
7. 🚧 HTTP Client Builder - Core complete, needs logging/cache integration
8. ⏳ Public API - Pending (1 subtask remaining)
9. ⏳ Documentation - Pending
10. 🚧 Testing - Partially complete (unit tests done, integration tests needed)
11. ⏳ Example Project - Pending
12. ⏳ Package Publishing Preparation - Pending

---

## 1. Project Setup ✅

- [x] 1.1 Create `pubspec.yaml` with package metadata and dependencies
- [x] 1.2 Create `analysis_options.yaml` with strict linting rules
- [x] 1.3 Create directory structure (`lib/`, `lib/src/`, `test/`)
- [x] 1.4 Create `.gitignore` for Dart/Flutter projects
- [x] 1.5 Create `README.md` with basic project description
- [x] 1.6 Create `LICENSE` file (choose license: MIT, Apache 2.0, etc.)
- [x] 1.7 Create `CHANGELOG.md` for version tracking

## 2. Core Types and Interfaces ✅

- [x] 2.1 Define `TokenProvider` interface in `lib/src/auth/token_provider.dart`
  - [x] 2.1.1 Add `getAccessToken()` method
  - [x] 2.1.2 Add `getRefreshToken()` method
  - [x] 2.1.3 Add `getAccessTokenExpiry()` method (UTC)
  - [x] 2.1.4 Add `getRefreshTokenExpiry()` method (UTC)
  - [x] 2.1.5 Add `setTokens()` method with expiry parameters
  - [x] 2.1.6 Add `clearTokens()` method
- [x] 2.2 Define `TokenRefreshResult` class in `lib/src/auth/token_refresh_result.dart`
  - [x] 2.2.1 Add required `accessToken` field
  - [x] 2.2.2 Add optional `refreshToken` field (for rotation)
  - [x] 2.2.3 Add optional `accessExpiry` and `refreshExpiry` fields
- [x] 2.3 Define custom exception hierarchy in `lib/src/exceptions/`
  - [x] 2.3.1 `AcdcException` base class (extends DioException)
  - [x] 2.3.2 `AcdcNetworkException` with `NetworkErrorType` enum
  - [x] 2.3.3 `AcdcAuthException`
  - [x] 2.3.4 `AcdcServerException`
  - [x] 2.3.5 `AcdcClientException`
  - [x] 2.3.6 `AcdcCacheException` with `CacheOperation` enum
  - [x] 2.3.7 Add `toMap()` method for structured logging
  - [x] 2.3.8 Add response body truncation (1KB limit)
  - [x] 2.3.9 Add URL redaction for sensitive parameters
- [x] 2.4 Define `LogLevel` enum in `lib/src/logging/log_level.dart`
  - [x] 2.4.1 Add values: debug, info, warning, error, none
- [x] 2.5 Define `AcdcLogger` typedef in `lib/src/logging/acdc_logger.dart`
- [x] 2.6 Write unit tests for exception types

## 3. Error Handling Interceptor ✅

- [x] 3.1 Create `ErrorInterceptor` class in `lib/src/interceptors/error_interceptor.dart`
- [x] 3.2 Implement HTTP status code to exception mapping
  - [x] 3.2.1 Map 401/403 to `AcdcAuthException`
  - [x] 3.2.2 Map 4xx (others) to `AcdcClientException`
  - [x] 3.2.3 Map 5xx to `AcdcServerException`
  - [x] 3.2.4 Handle 429 with Retry-After header parsing
- [x] 3.3 Implement network error handling
  - [x] 3.3.1 Map timeouts to `AcdcNetworkException`
  - [x] 3.3.2 Map connection errors to `AcdcNetworkException`
  - [x] 3.3.3 Include timeout type differentiation
- [x] 3.4 Add developer-friendly error message generation
- [x] 3.5 Implement response body truncation logic
- [x] 3.6 Implement URL redaction for sensitive parameters
- [x] 3.7 Handle edge cases (malformed responses, redirects)
- [x] 3.8 Ensure error interceptor runs AFTER auth interceptor attempts refresh
- [x] 3.9 Write unit tests for error interceptor
- [x] 3.10 Write tests for 401 bypass when auth interceptor handles it

## 4. Authentication Components ✅

- [x] 4.1 Create `AuthInterceptor` class in `lib/src/interceptors/auth_interceptor.dart`
  - [x] 4.1.1 Implement Bearer token injection in request headers
  - [x] 4.1.2 Handle existing Authorization header preservation
  - [x] 4.1.3 Implement token expiry validation before requests
- [x] 4.2 Implement proactive token refresh
  - [x] 4.2.1 Check `getAccessTokenExpiry()` before requests
  - [x] 4.2.2 Trigger refresh when within threshold (default: 60s, configurable)
  - [x] 4.2.3 Queue current request until refresh completes
  - [x] 4.2.4 Handle refresh failures (network vs auth errors)
  - [x] 4.2.5 Fall back to reactive refresh if expiry unavailable
- [x] 4.3 Implement reactive token refresh on 401
  - [x] 4.3.1 Detect 401 responses
  - [x] 4.3.2 Check for available refresh token
  - [x] 4.3.3 Trigger refresh and retry original request
  - [x] 4.3.4 Handle 401 without refresh token
  - [x] 4.3.5 Implement single retry limit (prevent infinite loops)
  - [x] 4.3.6 Clear tokens on repeated 401 after refresh
- [x] 4.4 Implement concurrent request queuing during refresh
  - [x] 4.4.1 Detect simultaneous token expiry across requests
  - [x] 4.4.2 Queue subsequent requests while first refreshes
  - [x] 4.4.3 Resume all queued requests with new token on success
  - [x] 4.4.4 Fail all queued requests on refresh failure
  - [x] 4.4.5 Implement refresh queue timeout (default: 10s)
- [x] 4.5 Implement token refresh endpoint support
  - [x] 4.5.1 Create OAuth 2.1 refresh request (POST with form-urlencoded)
  - [x] 4.5.2 Include grant_type, refresh_token, client_id (NO client_secret)
  - [x] 4.5.3 Parse refresh response (access_token, refresh_token, expires_in)
  - [x] 4.5.4 Use server Date header for clock skew handling
  - [x] 4.5.5 Call `setTokens()` with new tokens
  - [x] 4.5.6 Support custom refresh function via callback
- [x] 4.6 Implement token refresh error handling
  - [x] 4.6.1 Parse OAuth error responses (invalid_grant, etc.)
  - [x] 4.6.2 Map OAuth errors to specific messages
  - [x] 4.6.3 Clear tokens on auth errors (invalid_grant)
  - [x] 4.6.4 Preserve tokens on network/server errors
  - [x] 4.6.5 Implement exponential backoff for 5xx errors
- [x] 4.7 Implement token refresh isolation
  - [x] 4.7.1 Create separate minimal Dio instance for refresh requests
  - [x] 4.7.2 Bypass auth, cache, and custom interceptors
  - [x] 4.7.3 Include only error interceptor and minimal logging
  - [x] 4.7.4 Redact refresh_token and access_token in logs
- [x] 4.8 Handle TokenProvider exceptions
  - [x] 4.8.1 Catch `getAccessToken()` exceptions → proceed without auth
  - [x] 4.8.2 Catch `getRefreshToken()` exceptions → fail with clear error
  - [x] 4.8.3 Catch `setTokens()` exceptions → fail refresh, log error
  - [x] 4.8.4 Catch `clearTokens()` exceptions → log warning, continue
  - [x] 4.8.5 Ensure exceptions never crash the app
- [x] 4.9 Handle logout during active refresh
  - [x] 4.9.1 Detect logout call while refresh in progress
  - [x] 4.9.2 Cancel in-progress refresh request
  - [x] 4.9.3 Fail queued requests with logout indication
  - [x] 4.9.4 Proceed with normal logout flow
- [x] 4.10 Create `AcdcAuthManager` class in `lib/src/auth/acdc_auth_manager.dart`
  - [x] 4.10.1 Implement `logout()` method with token revocation
  - [x] 4.10.2 Implement `refreshNow()` method for forced refresh
  - [x] 4.10.3 Implement `clearCache()` method
  - [x] 4.10.4 Store reference to cache and auth interceptor
- [x] 4.11 Create `AcdcAuth` Dart extension on Dio
  - [x] 4.11.1 Add `auth` getter returning `AcdcAuthManager`
  - [x] 4.11.2 Store manager reference in Dio options
  - [x] 4.11.3 Handle case when auth is not configured
- [x] 4.12 Implement token revocation for logout
  - [x] 4.12.1 POST to revocation endpoint with token and token_type_hint
  - [x] 4.12.2 Revoke refresh token first, then access token
  - [x] 4.12.3 Handle revocation failures gracefully (best-effort)
  - [x] 4.12.4 Always clear tokens locally regardless of revocation success
- [x] 4.13 Support token rotation
  - [x] 4.13.1 Update both tokens when new refresh_token in response
  - [x] 4.13.2 Retain old refresh token if not rotated
- [x] 4.14 Handle expired refresh tokens
  - [x] 4.14.1 Check `getRefreshTokenExpiry()` before refresh
  - [x] 4.14.2 Clear tokens and fail if refresh token expired
- [x] 4.15 Write unit tests for auth interceptor
- [x] 4.16 Write integration tests for token refresh flow
- [x] 4.17 Write tests for concurrent request queuing
- [x] 4.18 Write tests for logout during refresh

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

## 7. HTTP Client Builder 🚧

- [x] 7.1 Create `AcdcClientBuilder` class in `lib/src/builder/acdc_client_builder.dart`
  - [x] 7.1.1 Implement immutable builder pattern
  - [x] 7.1.2 Each configuration method returns new builder instance
- [x] 7.2 Implement fluent builder methods:
  - [x] 7.2.1 `withBaseUrl(String url)`
  - [x] 7.2.2 `withTimeout(Duration timeout)`
  - [x] 7.2.3 `withTokenProvider(TokenProvider provider)`
  - [x] 7.2.4 `withTokenRefreshEndpoint({required String url, required String clientId})`
  - [x] 7.2.5 `withCustomTokenRefresh(Future<TokenRefreshResult> Function(String) refreshFn)`
  - [x] 7.2.6 `withTokenRevocationEndpoint(String url)`
  - [x] 7.2.7 `withTokenRefreshThreshold(Duration threshold)`
  - [x] 7.2.8 `withLogLevel(LogLevel level)`
  - [x] 7.2.9 `withLogger(AcdcLogger logger)`
  - [x] 7.2.10 `withSensitiveFields(List<dynamic> fields)`
  - [x] 7.2.11 `withSlowRequestThreshold(Duration threshold)`
  - [x] 7.2.12 `withLargePayloadThreshold(int bytes)`
  - [x] 7.2.13 `withCache(CacheConfig config)`
  - [x] 7.2.14 `disableCache()`
  - [x] 7.2.15 `withInterceptor(Interceptor interceptor)`
- [x] 7.3 Implement `build()` method
  - [x] 7.3.1 Create new Dio instance each time
  - [x] 7.3.2 Allow builder reuse for multiple instances
  - [x] 7.3.3 Set base URL if configured
  - [x] 7.3.4 Set default timeouts (30s for connect/send/receive)
  - [x] 7.3.5 Configure interceptor chain in correct order
  - [x] 7.3.6 Return standard Dio instance (not wrapper)
- [x] 7.4 Configure interceptor chain with correct order
  - [x] 7.4.1 Request phase: Logging → Auth → Cache
  - [x] 7.4.2 Response phase: Cache → Auth → Error → Logging
  - [x] 7.4.3 Append custom interceptors at end
- [x] 7.5 Implement builder validation
  - [x] 7.5.1 Validate timeout is positive
  - [x] 7.5.2 Validate base URL format
  - [x] 7.5.3 Reject null required parameters
  - [x] 7.5.4 Last configuration wins on conflicts
- [x] 7.6 Set up AcdcAuthManager
  - [x] 7.6.1 Create manager instance if auth configured
  - [x] 7.6.2 Store in Dio options for extension access
  - [x] 7.6.3 Provide informative errors if auth not configured
- [x] 7.7 Write unit tests for builder
- [x] 7.8 Write tests for builder immutability
- [x] 7.9 Write tests for build() reusability
- [x] 7.10 Write integration tests for complete client

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

## 10. Testing 🚧

- [x] 10.1 Unit tests for all components
  - [x] 10.1.1 Exception types
  - [x] 10.1.2 Error interceptor
  - [x] 10.1.3 Auth interceptor
  - [ ] 10.1.4 Logging interceptor
  - [ ] 10.1.5 Cache configuration
  - [x] 10.1.6 Builder
- [ ] 10.2 Integration tests
  - [ ] 10.2.1 Complete client with all features enabled
  - [x] 10.2.2 Token refresh flow (proactive and reactive)
  - [x] 10.2.3 Concurrent request queuing
  - [ ] 10.2.4 Logout during refresh
  - [ ] 10.2.5 TokenProvider exception handling
  - [ ] 10.2.6 Cache initialization failure
  - [ ] 10.2.7 User-based cache isolation
  - [ ] 10.2.8 Offline caching
  - [ ] 10.2.9 Custom logger integration
  - [ ] 10.2.10 Builder immutability and reusability
- [ ] 10.3 Test with openapi-generated client (manual integration test)
- [x] 10.4 Run `dart analyze` with zero issues
- [x] 10.5 Run `dart format` on all files
- [x] 10.6 Achieve 80%+ code coverage
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
