# Offline Support

Dart-ACDC is designed to handle flaky networks and offline states gracefully.

## Offline Interceptor

The `OfflineInterceptor` sits at the start of the request chain. When the device is offline:
1.  Checks if a valid (or stale) cache entry exists.
2.  If found, returns the cached response immediately.
3.  If not found, it "fails fast" with an `AcdcNetworkException` (instead of waiting for a connection timeout).

## Configuration

Enable/Disable offline detection logic in the builder:

```dart
final dio = AcdcClientBuilder()
    .withOfflineDetection(failFast: true) // Default
    .build();
```

-   **failFast**:
    -   `true`: Throws `AcdcNetworkException`(type: `connectionError`) immediately if offline and no cache is found.
    -   `false`: Attempts the network request anyway (reliance on system timeouts).

## Forcing Network

Sometimes you want to bypass the offline check (e.g., to test a specific endpoint or if the OS connectivity check is flaky).

```dart
try {
  await dio.get('/critical-action', options: Options(
    extra: {'force_network': true}, 
  ));
} on AcdcNetworkException {
  // Handle offline explicitly
}
```

## Best Practices

1.  **Read Operations**: Rely on the default behavior. If the user is offline, they'll see cached data or an error.
2.  **Write Operations (POST/PUT)**: These will fail fast when offline. Queue them locally in your app logic if you need "sync later" functionality (this library does not implement a persistent mutation queue).
