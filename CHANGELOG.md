## 0.3.0 - 2026-02-14

> [!IMPORTANT]
> This release introduces breaking changes to cache behavior for safer defaults and includes significant improvements to error handling, testing, and token management.

### Breaking Changes

*   **BREAKING**: Changed default `staleIfErrorCodes` from `[401, 403]` to `[500, 502, 503, 504]` (server errors only). This prevents authentication failures from being masked by stale cache. If you relied on the previous behavior, explicitly set `staleIfErrorCodes: [401, 403, 500, 502, 503, 504]` in your `CacheConfig`.

### Features

*   Added configurable `staleIfErrorCodes` field to `CacheConfig` to customize which HTTP status codes trigger stale cache serving when `staleIfError` is enabled.
*   Convert `badCertificate` exceptions to `AcdcSecurityException` for consistent error handling.
*   Exported `AcdcSecurityException` from public API for better error handling capabilities.

### Improvements

*   Improved SocketException handling and aligned TokenProvider contract implementations.
*   Made `refreshNow()` actually force a refresh regardless of token expiry status.
*   Clarified and enforced consistent `setTokens()` partial update semantics.
*   Replaced string-based network error detection with type checking for more reliable network error detection.
*   Made `LoggingInterceptor._isLogging` flag instance-scoped to prevent race conditions.
*   Fixed cache clearing for user-isolated cache entries with `clearCacheForUrl()`.
*   Improved clock skew parsing to use `HttpDate.parse()` for RFC 1123 Date header parsing.

### Documentation

*   Clarified `refreshNow()` forced refresh behavior and exception handling.
*   Corrected documentation and example code inconsistencies.
*   Clarified that `maxSize` is not enforced and deprecated the parameter.
*   Fixed git hook setup instructions.
*   Corrected example to use proper API.

### Testing

*   Improved `PinningHttpClient` test coverage from 12.5% to 100%.
*   Added comprehensive test coverage for `AcdcSecurityException.fromDioException`.
*   Added unit tests for `forceRefresh()` method.
*   Added unit test for SocketException type checking.
*   Improved overall project coverage to 93.56%.

### Bug Fixes

*   Fixed incorrect assertion in `refreshNow` test.
*   Removed unreachable badCertificate case from `_isNetworkError`.
*   Fixed `clearCacheForUrl()` to properly delete user-isolated cache entries.
*   Removed dead ternary in CachePolicy assignment.
*   Unified maxStale logic in dual CacheOptions objects.

### Maintenance

*   Removed macOS and Windows test jobs from CI.
*   Updated dependencies: `actions/checkout` v4→v6, `codecov/codecov-action` v4→v5.
*   Excluded test certificates from secret scanning.
*   Removed unnecessary HTTP logging from test servers.

## 0.2.0

> [!IMPORTANT]
> This release introduces breaking changes to the caching implementation and major dependency upgrades.

*   **BREAKING**: Migrated from `dio_cache_interceptor_file_store` to `http_cache_file_store` for better file handling and desktop support.
*   **BREAKING**: Upgraded `flutter_secure_storage` to `^10.0.0`. This may require updates to your platform-specific configuration (e.g., Android `minSdkVersion`).
*   **BREAKING**: Upgraded `dio_cache_interceptor` to `^4.0.5`.
*   Upgraded `test` to `^1.26.3` and `flutter_lints` to `^6.0.0`.
*   Resolved dependency conflicts and fixed new lint warnings.

## 0.1.0

*   Initial release of `dart_acdc`.
*   Zero-config Dio client with built-in authentication, caching, logging, and error handling.
