# Dart-ACDC Examples

This directory contains examples demonstrating how to use dart_acdc.

## Running the Example

```bash
cd example
flutter pub get
dart example.dart
```

## Examples Included

### Basic Usage
```dart
final dio = AcdcClientBuilder().build();
final response = await dio.get('https://api.example.com/data');
```

### With Authentication
```dart
final dio = AcdcClientBuilder()
    .withAuth(
      tokenProvider: MyTokenProvider(),
      refreshUrl: 'https://api.example.com/auth/refresh',
    )
    .build();
```

### With Caching
```dart
final dio = AcdcClientBuilder()
    .withCache(
      enabled: true,
      maxAge: Duration(hours: 1),
    )
    .build();
```

### With Custom Logging
```dart
final dio = AcdcClientBuilder()
    .withLogging(
      logDelegate: MyLogDelegate(),
      enableInProduction: false,
    )
    .build();
```

## See Also

- [Main README](../README.md) - Package overview and installation
- [Documentation](../doc) - Detailed documentation
- [API Reference](https://pub.dev/documentation/dart_acdc) - Complete API docs
