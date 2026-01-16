# Dart ACDC

**A**uthentication, **C**aching, **D**ebugging, **C**lient - A zero-config, opinionated HTTP client for Flutter mobile apps.

## Overview

Dart-ACDC provides a production-ready HTTP client built on top of [Dio](https://pub.dev/packages/dio) with:

- **Authentication**: Automatic token injection, refresh, and revocation (OAuth 2.1)
- **Caching**: Intelligent HTTP caching with user isolation and offline support
- **Logging**: Environment-aware logging with sensitive data redaction
- **Error Handling**: Type-safe exceptions with developer-friendly messages

Designed to be the "missing link" between [OpenAPI Generator](https://github.com/OpenAPITools/openapi-generator) Dart clients and production-ready Flutter apps.

## Features

- ✅ **Zero-config default**: Works out of the box with sensible defaults
- ✅ **Builder pattern**: Progressive disclosure for advanced configuration
- ✅ **Type-safe**: Full Dart type safety and null safety
- ✅ **Testable**: Easy mocking and testing
- ✅ **Production-ready**: Battle-tested patterns for mobile apps
- ✅ **Efficient**: Automatic request deduplication to save bandwidth

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  dart_acdc: ^0.1.0
```

Then run:

```bash
flutter pub get
```

## Quick Start

### Basic Usage

```dart
import 'package:dart_acdc/dart_acdc.dart';

// Zero-config client
final dio = AcdcClientBuilder().build();

// Make requests
final response = await dio.get('https://api.example.com/data');
```

### With Authentication (Zero-Config)

Dart-ACDC comes with a secure, encrypted token store (`SecureTokenProvider`) out of the box. You don't need to write any storage code.

```dart
import 'package:dart_acdc/dart_acdc.dart';

final dio = AcdcClientBuilder()
  .withBaseUrl('https://api.example.com')
  // Automatically uses FlutterSecureStorage
  .withTokenRefreshEndpoint(
    url: 'https://api.example.com/oauth/token',
    clientId: 'your-client-id',
  )
  .withInitialTokens(
    accessToken: '...',
    refreshToken: '...',
  )
  .build();

// All subsequent requests will have the token injected and refreshed automatically
final response = await dio.get('/protected/endpoint');

// Logout: clears tokens from secure storage and revokes them if endpoint provided
await dio.auth.logout();
```

### With OpenAPI Generator

1. Generate your client using `openapi-generator-cli` (dart-dio generator).
2. Create your configured Dio instance with Dart-ACDC.
3. Pass it to your generated API client.

```dart
import 'package:your_openapi_client/api.dart';
import 'package:dart_acdc/dart_acdc.dart';

final dio = AcdcClientBuilder()
  .withBaseUrl('https://api.example.com')
  .withTokenRefreshEndpoint(...)
  .build();

// Inject into OpenAPI-generated client
// The generated DefaultApi (and others) accept a Dio instance in the constructor.
final api = DefaultApi(dio);

// Now all API calls have auth, caching, logging, and error handling!
final users = await api.getUsers();
```

## Advanced Usage

### Custom Token Storage

If you need to store tokens somewhere other than `flutter_secure_storage` (e.g., Hive or SharedPreferences), implement `TokenProvider`:

```dart
class MyTokenProvider implements TokenProvider {
  @override
  Future<String?> getAccessToken() async { ... }
  // ... implement other methods
}

final dio = AcdcClientBuilder()
  .withTokenProvider(MyTokenProvider())
  .build();
```

## Configuration

### Logging & Redaction

By default, logs are pretty-printed to the console. You can redact sensitive keys to prevent leaking secrets.

```dart
final dio = AcdcClientBuilder()
  .withLogLevel(LogLevel.debug)
  .withSensitiveFields(['password', 'accessToken', 'secret']) // Redacts these keys in JSON
  .withLogger((message, level, metadata) {
    // Optional: pipe logs to Crashlytics or Datadog
    Crashlytics.instance.log(message);
  })
  .build();
```

### Caching

```dart
final dio = AcdcClientBuilder()
  .withCache(CacheConfig(
    ttl: Duration(hours: 1),
    maxSize: 10 * 1024 * 1024, // 10 MB
    // Encrypted on disk by default
    inMemory: true,
  ))
  .build();

// Manually clear cache if needed
await dio.auth.clearCache();
```

### Timeouts

```dart
final dio = AcdcClientBuilder()
  .withTimeout(Duration(seconds: 30))
  .build();
```

### Request Deduplication

By default, Dart-ACDC deduplicates simultaneous identical requests (same method, URL, headers, and data) to prevent redundant network calls.

```dart
final dio = AcdcClientBuilder()
  // Disable deduplication if needed
  .withDeduplication(enabled: false)
  .build();
```

## Error Handling

Dart-ACDC provides type-safe exception handling:

```dart
try {
  await dio.get('/endpoint');
} on AcdcAuthException catch (e) {
  // Handle authentication errors (401, 403)
  print('Auth error: ${e.message}');
} on AcdcNetworkException catch (e) {
  // Handle network errors (timeout, no connection)
  print('Network error: ${e.message}');
} on AcdcServerException catch (e) {
  // Handle server errors (5xx)
  print('Server error: ${e.statusCode}');
} on AcdcClientException catch (e) {
  // Handle client errors (4xx except 401)
  print('Client error: ${e.statusCode}');
}
```

## Requirements

- Dart SDK: `>=3.0.0 <4.0.0`
- Flutter: `>=3.10.0`

## Development

### Running Tests

```bash
dart test
```

### Code Coverage

Run tests with coverage reporting:

```bash
./scripts/coverage.sh
```

Current coverage: **91.76%** ✅ (exceeds 80% target)

## Security Best Practices

Dart-ACDC is built with security as a priority:

1.  **Secure Storage**: All tokens are stored using specific OS-level encryption (Keychain on iOS, EncryptedSharedPreferences on Android) by default.
2.  **Memory Protection**: Authentication headers are stripped from logs by default.
3.  **Cache Encryption**: Response data cached on disk is always AES-256 encrypted.
4.  **Least Privilege**: The library only requests the permissions it needs.

## Documentation

- [API Documentation](https://pub.dev/documentation/dart_acdc/latest/)
- [Examples](https://github.com/jhosm/dart-acdc-examples)
- [Changelog](CHANGELOG.md)

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

## Support

- [Issue Tracker](https://github.com/jhosm/dart-acdc/issues)
- [Discussions](https://github.com/jhosm/dart-acdc/discussions)
