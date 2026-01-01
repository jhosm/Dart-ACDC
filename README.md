# Dart ACDC

**A**uthentication, **C**aching, **D**ebugging, **C**lient - A zero-config, opinionated HTTP client for Flutter mobile apps.

## Overview

Dart-ACDC provides a production-ready HTTP client built on top of [Dio](https://pub.dev/packages/dio) with:

- **Authentication**: Automatic token injection, refresh, and revocation (OAuth 2.1)
- **Caching**: Intelligent HTTP caching with user isolation and offline support
- **Logging**: Environment-aware logging with sensitive data redaction
- **Error Handling**: Type-safe exceptions with developer-friendly messages

Designed to integrate seamlessly with [OpenAPI Generator](https://github.com/OpenAPITools/openapi-generator) Dart clients.

## Features

- ✅ **Zero-config default**: Works out of the box with sensible defaults
- ✅ **Builder pattern**: Progressive disclosure for advanced configuration
- ✅ **Type-safe**: Full Dart type safety and null safety
- ✅ **Testable**: Easy mocking and testing
- ✅ **Production-ready**: Battle-tested patterns for mobile apps

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

### With Authentication

```dart
import 'package:dart_acdc/dart_acdc.dart';

// Implement TokenProvider (e.g., using flutter_secure_storage)
class MyTokenProvider implements TokenProvider {
  // ... implement token storage methods
}

final dio = AcdcClientBuilder()
  .withBaseUrl('https://api.example.com')
  .withTokenProvider(MyTokenProvider())
  .withTokenRefreshEndpoint(
    url: 'https://api.example.com/auth/refresh',
    clientId: 'your-client-id',
  )
  .build();

// Tokens are automatically injected and refreshed
final response = await dio.get('/protected/endpoint');

// Logout with token revocation
await dio.auth.logout();
```

### With OpenAPI Generator

```dart
import 'package:your_openapi_client/api.dart';
import 'package:dart_acdc/dart_acdc.dart';

final dio = AcdcClientBuilder()
  .withBaseUrl('https://api.example.com')
  .withTokenProvider(MyTokenProvider())
  .build();

// Inject into OpenAPI-generated client
final api = DefaultApi(dio);
final users = await api.getUsers();
```

## Configuration

### Logging

```dart
final dio = AcdcClientBuilder()
  .withLogLevel(LogLevel.debug) // debug, info, warning, error, none
  .withLogger((message, level, metadata) {
    // Custom logger integration
    myLogger.log(message, level: level);
  })
  .build();
```

### Caching

```dart
final dio = AcdcClientBuilder()
  .withCache(CacheConfig(
    ttl: Duration(hours: 1),
    maxSize: 10 * 1024 * 1024, // 10 MB
    encrypted: true,
    inMemory: true,
  ))
  .build();

// Clear cache
await dio.auth.clearCache();
```

### Timeouts

```dart
final dio = AcdcClientBuilder()
  .withTimeout(Duration(seconds: 30))
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

## Documentation

- [API Documentation](https://pub.dev/documentation/dart_acdc/latest/)
- [Examples](https://github.com/yourusername/dart-acdc/tree/main/example)
- [Changelog](CHANGELOG.md)

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

## Support

- [Issue Tracker](https://github.com/yourusername/dart-acdc/issues)
- [Discussions](https://github.com/yourusername/dart-acdc/discussions)
