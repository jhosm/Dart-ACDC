# Caching & Stale-While-Revalidate

Dart-ACDC includes a powerful 2-tier caching system (Memory + Disk) that follows HTTP caching directives while providing advanced features like user isolation and Stale-While-Revalidate (SWR).

## Configuration

Control caching behavior via the `CacheConfig` object passed to the builder.

```dart
final dio = AcdcClientBuilder()
    .withCache(CacheConfig(
      // Expiration
      ttl: Duration(hours: 1),
      
      // Storage Limits
      maxSize: 20 * 1024 * 1024, // 20 MB disk cache
      inMemoryMaxSize: 5 * 1024 * 1024, // 5 MB RAM cache
      
      // Behavior
      cacheAuthenticatedRequests: true, // Default: true
      encrypted: true, // Encrypt disk storage
    ))
    .build();
```

### Disabling Cache

You can disable caching globally or per request.

**Globally:**
```dart
.disableCache()
```

**Per Request:**
```dart
// Force network fetch (bypasses cache read, updates cache on success)
final response = await dio.get('/data', options: Options(
  extra: {'refresh': true}, 
));

// Disable cache entirely for this request (no read, no write)
final response = await dio.get('/data', options: Options(
  extra: {'no_cache': true},
));
```

## Storage Architecture

1.  **Memory Tier**: LRU cache for instance access (RAM).
2.  **Persistent Tier**: Hive-based disk storage.

### Security
- **User Isolation**: Cache keys automatically include the user ID (from the auth token). When a user logs out, their cache is cleared automatically, preventing data leaks between users on shared devices.
- **Encryption**: Enable `encrypted: true` in `CacheConfig` to encrypt disk storage using AES-256 (keys managed by platform secure storage).

## Stale-While-Revalidate (SWR)

SWR is a strategy where the client returns cached (stale) data immediately while fetching fresh data in the background.

### Using `streamRequest`

To use SWR, use the `streamRequest` extension method instead of standard `get`/`post`. This returns a `Stream` that may emit two items:
1.  The cached response (if available).
2.  The fresh network response.

```dart
// Use streamRequest for SWR behavior
dio.streamRequest<Map<String, dynamic>>(
  '/user/profile',
  options: Options(method: 'GET'),
).listen(
  (response) {
    if (response.isFromCache) {
      print('Showing cached data...');
    } else {
      print('Showing fresh data!');
    }
    updateUi(response.data);
  },
  onError: (error) {
    // Handle errors (e.g. network fail while revalidating)
    print('Error: $error');
  },
);
```

**Note**: `streamRequest` automatically handles caching headers and logic. If the cache is missing or expired beyond the "stale" limit, it will only emit the network response.

### Identifying Response Source

You can inspect `response.extra['acdc_source']` to determine the exact source of a response:

| Value | Description |
| :--- | :--- |
| `'cache'` | Standard cache hit. |
| `'network'` | Standard network response (cache miss, skip, or refresh). |
| `'cache_stale'` | **SWR**: The initial stale response emitted primarily from cache. |
| `'network_fresh'` | **SWR**: The subsequent fresh response emitted from a background network refresh. |

```dart
if (response.extra['acdc_source'] == 'cache_stale') {
  showBadge('STALE');
} else if (response.extra['acdc_source'] == 'network_fresh') {
  showBadge('FRESH');
}
```
