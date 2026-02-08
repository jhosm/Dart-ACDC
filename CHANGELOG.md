## Unreleased

> [!IMPORTANT]
> This release introduces breaking changes to cache behavior for safer defaults.

*   **BREAKING**: Changed default `staleIfErrorCodes` from `[401, 403]` to `[500, 502, 503, 504]` (server errors only). This prevents authentication failures from being masked by stale cache. If you relied on the previous behavior, explicitly set `staleIfErrorCodes: [401, 403, 500, 502, 503, 504]` in your `CacheConfig`.
*   **NEW**: Added configurable `staleIfErrorCodes` field to `CacheConfig` to customize which HTTP status codes trigger stale cache serving when `staleIfError` is enabled.

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
