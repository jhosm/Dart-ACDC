# Logging Specification

## ADDED Requirements

### Requirement: Environment-Aware Logging

The library SHALL automatically detect the environment (debug vs release) and adjust logging behavior accordingly.

#### Scenario: Debug mode logging

- **WHEN** the app runs in debug mode (`kDebugMode == true`)
- **THEN** detailed, pretty-printed request/response logs are enabled
- **AND** logs include headers, body, and timing information
- **AND** logs are formatted for developer readability

#### Scenario: Release mode logging

- **WHEN** the app runs in release mode (`kDebugMode == false`)
- **THEN** minimal logging is enabled
- **AND** sensitive data (tokens, passwords) is redacted
- **AND** logs include only essential information (status code, duration, URL)

### Requirement: Log Level Configuration

The library SHALL support configurable log levels for explicit control over logging verbosity.

#### Scenario: Debug log level

- **WHEN** log level is set to `LogLevel.debug`
- **THEN** all request/response details are logged
- **AND** headers and body content are included

#### Scenario: Info log level

- **WHEN** log level is set to `LogLevel.info`
- **THEN** basic request information is logged (method, URL, status code)
- **AND** headers and body content are excluded

#### Scenario: None log level

- **WHEN** log level is set to `LogLevel.none`
- **THEN** no HTTP logging occurs
- **AND** the logging interceptor is not added to the chain

### Requirement: Sensitive Data Redaction

The library SHALL redact sensitive data from logs in production environments.

#### Scenario: Authorization header redaction

- **WHEN** a request includes an Authorization header
- **AND** the app is in release mode
- **THEN** the header value is replaced with `[REDACTED]` in logs
- **AND** the actual header is still sent with the request

#### Scenario: Password field redaction

- **WHEN** a request body contains fields named `password`, `secret`, `token`, or `apiKey`
- **AND** the app is in release mode
- **THEN** the field values are replaced with `[REDACTED]` in logs
- **AND** the actual values are still sent with the request

### Requirement: Request Duration Tracking

The library SHALL track and log the duration of HTTP requests for performance monitoring.

#### Scenario: Request timing in debug mode

- **WHEN** a request completes
- **AND** debug logging is enabled
- **THEN** the log includes the request duration in milliseconds
- **AND** the duration is formatted for readability (e.g., "245ms")

#### Scenario: Slow request warning

- **WHEN** a request takes longer than a threshold (e.g., 3 seconds)
- **AND** logging is enabled
- **THEN** a warning is logged indicating a slow request
- **AND** the log includes the request URL and duration

### Requirement: Pretty Dio Logger Integration

The library SHALL integrate `pretty_dio_logger` for enhanced debug logging.

#### Scenario: Pretty logger in debug mode

- **WHEN** debug mode is active
- **THEN** `pretty_dio_logger` is added to the interceptor chain
- **AND** requests/responses are formatted with colors and indentation
- **AND** the output is optimized for console readability

### Requirement: Structured Logging

The library SHALL include structured metadata in logs for easier filtering and analysis.

#### Scenario: Log metadata

- **WHEN** a request is logged
- **THEN** the log includes structured metadata:
  - Request ID (if available)
  - Timestamp
  - HTTP method
  - URL
  - Status code
  - Duration

### Requirement: Custom Logger Support

The library SHALL allow developers to provide a custom logger implementation.

#### Scenario: Custom logger injection

- **WHEN** a developer provides a custom logger via `withLogger()`
- **THEN** the custom logger is used instead of the default
- **AND** the custom logger receives all log events
- **AND** the custom logger can implement platform-specific logging (e.g., Firebase Crashlytics)

```dart
final dio = AcdcClientBuilder()
  .withLogger((message, level) {
    myCustomLogger.log(level, message);
  })
  .build();
```
