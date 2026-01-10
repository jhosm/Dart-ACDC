# Change: Add Stale-While-Revalidate Caching

## Why
Stale-while-revalidate allows apps to show data instantly from the cache while updating it in the background, providing the best perceived performance and data freshness.

## What Changes
- Add `staleWhileRevalidate` policy to `CacheConfig`
- Implement background revalidation logic in `CacheInterceptor` or utilize `dio_cache_interceptor` capabilities
- Support streaming responses (emit stale, then fresh)

## Impact
- Affected specs: `caching`
- Affected code: `CacheConfig`, `CacheInterceptor`
