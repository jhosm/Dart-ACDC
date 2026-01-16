# Getting Started with Dart-ACDC

Dart-ACDC (Advanced Client for Dio Communication) is a production-ready HTTP client built on top of [Dio](https://pub.dev/packages/dio), adding essential features like authentication, caching, and offline support out of the box.

## Installation

Add dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  dart_acdc: ^0.1.0 # Use the latest version
  dio: ^5.0.0
```

## Basic Usage

The easiest way to create a client is using the `AcdcClientBuilder`.

### Minimal Setup

```dart
import 'package:dart_acdc/dart_acdc.dart';

void main() async {
  final dio = AcdcClientBuilder()
      .withBaseUrl('https://api.example.com')
      .build();

  final response = await dio.get('/posts/1');
  print(response.data);
}
```

### Full Configuration

```dart
final dio = AcdcClientBuilder()
    .withBaseUrl('https://api.example.com')
    .withTimeout(Duration(seconds: 30))
    // Caching
    .withCache(CacheConfig(
      ttl: Duration(hours: 1),
      maxSize: 10 * 1024 * 1024, // 10 MB
    ))
    // Logging
    .withLogLevel(LogLevel.debug)
    .withSensitiveFields(['password', 'apiKey'])
    // Offline Support
    .withOfflineDetection(failFast: true)
    .build();
```

## Builders vs. Direct Instantiation

Dart-ACDC uses an immutable builder pattern. Each `with...` method returns a new builder instance.

```dart
final baseBuilder = AcdcClientBuilder()
    .withBaseUrl('https://api.example.com');

// Create two independent clients with different timeouts
final fastClient = await baseBuilder
    .withTimeout(Duration(seconds: 5))
    .build();

final slowClient = await baseBuilder
    .withTimeout(Duration(seconds: 60))
    .build();
```

## Error Handling

All exceptions are normalized into `AcdcException` subclasses:

- `AcdcAuthException`: 401/403 errors or token refresh failures.
- `AcdcNetworkException`: Connectivity issues (timeout, DNS, offline).
- `AcdcServerException`: 5xx server errors.
- `AcdcClientException`: 4xx client errors (bad request, not found).

```dart
try {
  await dio.get('/secure-data');
} on AcdcAuthException catch (e) {
  // Handle unauthorized access (e.g., redirect to login)
} on AcdcNetworkException catch (e) {
  // Handle offline state or connection problems
}
```

## Next Steps

- [Authentication Guide](authentication.md) - Set up auto-refresh and token storage.
- [Caching & SWR](caching.md) - Configure caching policies and Stale-While-Revalidate.
- [Offline Support](offline.md) - Handle offline states and fail-fast behavior.
- [Request Deduplication](deduplication.md) - Optimize redundant network calls.
- [Certificate Pinning](certificate_pinning.md) - Validating server identity.
- [Logging & Errors](logging_and_errors.md) - Debugging and exception handling.
