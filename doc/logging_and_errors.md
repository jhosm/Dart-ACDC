# Logging & Error Handling

## Logging

Dart-ACDC provides built-in logging to help debug network interactions.

### Log Levels

Configure the verbosity of logs:

```dart
final dio = AcdcClientBuilder()
    // Options: none, error, warning, info, debug, verbose
    .withLogLevel(LogLevel.debug) 
    .build();
```

### Sensitive Data Redaction

Protect user privacy by redacting sensitive fields from JSON bodies and URL parameters:

```dart
.withSensitiveFields(['password', 'token', 'access_token', 'credit_card'])
```

This will replace values with `[REDACTED]` in the logs.

### Custom Logger Integration

To pipe ACDC logs into your app's main logging system (e.g., sentry, firebase crashlytics, or a console logger):

1.  Implement `AcdcLogDelegate`:

    ```dart
    class MyLogger implements AcdcLogDelegate {
      @override
      void log(String message, LogLevel level, Map<String, dynamic> metadata) {
        // Integrate with your logger
        print('[$level] $message $metadata');
      }
    }
    ```

2.  Pass it to the builder:

    ```dart
    .withLogDelegate(MyLogger())
    ```

## Error Handling

The library normalizes all errors into the `AcdcException` hierarchy.

### Exception Types

| Exception Class | Description |
| :--- | :--- |
| `AcdcException` | Base class for all library exceptions. |
| `AcdcAuthException` | Authentication failure (401, refresh failed). |
| `AcdcNetworkException` | Connectivity issues (offline, timeout, DNS). |
| `AcdcServerException` | Server returned 5xx status code. |
| `AcdcClientException` | Server returned 4xx status code (e.g., 400 Bad Request). |
| `AcdcSecurityException` | Certificate pinning or security check failure. |

### Best Practices

Catch specific exceptions to handle different failure modes:

```dart
try {
  await client.get('/data');
} on AcdcAuthException {
  // Redirect to login
} on AcdcNetworkException {
  // Show "Check internet connection" toast
} on AcdcServerException {
  // Show "Server maintenance" message
} catch (e) {
  // Generic error fallback
}
```
