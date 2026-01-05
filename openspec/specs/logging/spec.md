# logging Specification

## Purpose
TBD - created by archiving change add-core-library-architecture. Update Purpose after archive.
## Requirements
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
- **THEN** no HTTP request/response logging occurs
- **AND** the logging interceptor is not added to the chain
- **BUT** error and warning logs are still emitted

#### Scenario: Explicit log level configuration

- **WHEN** a developer configures a log level via `withLogLevel()`
- **THEN** the specified log level is used instead of the environment default
- **AND** the configuration overrides `kDebugMode` detection
- **AND** developers have explicit control over logging verbosity

```dart
// Override default to use info level even in debug mode
final dio = AcdcClientBuilder()
  .withLogLevel(LogLevel.info)
  .build();

// Disable all HTTP logging in debug mode
final dio = AcdcClientBuilder()
  .withLogLevel(LogLevel.none)
  .build();

// Force debug logging even in release mode (not recommended)
final dio = AcdcClientBuilder()
  .withLogLevel(LogLevel.debug)
  .build();
```

#### Scenario: Configuration priority

- **WHEN** both `kDebugMode` and explicit `LogLevel` are specified
- **THEN** the explicit `LogLevel` takes precedence over the environment default
- **AND** developers can override debug mode behavior if needed

**Example:** Setting `LogLevel.none` in debug mode will disable logging despite `kDebugMode == true`

### Requirement: Sensitive Data Redaction

The library SHALL redact sensitive data from logs in production environments.

#### Scenario: Authorization header redaction

- **WHEN** a request includes an Authorization header
- **AND** the app is in release mode
- **THEN** the header value is replaced with `[REDACTED]` in logs
- **AND** the actual header is still sent with the request

#### Scenario: Sensitive field redaction

- **WHEN** a request body or headers contain sensitive fields
- **AND** the app is in release mode OR sensitive data redaction is explicitly enabled
- **THEN** the field values are replaced with `[REDACTED]` in logs
- **AND** the actual values are still sent with the request

**Sensitive field patterns** (case-insensitive matching):

- Exact matches: `password`, `secret`, `token`, `apiKey`, `api_key`, `accessToken`, `refreshToken`, `pin`, `ssn`, `creditCard`, `cvv`, `privateKey`
- Pattern matches: Fields ending with `_token`, `_secret`, `_key`, `_password`

#### Scenario: Custom sensitive field configuration

- **WHEN** a developer provides custom sensitive field patterns via `withSensitiveFields()`
- **THEN** the provided patterns are used in addition to the default patterns
- **AND** developers can specify both exact matches and regex patterns

```dart
final dio = AcdcClientBuilder()
  .withSensitiveFields(['customSecret', RegExp(r'.*_credential$')])
  .build();
```

### Requirement: Request Duration Tracking

The library SHALL track and log the duration of HTTP requests for performance monitoring.

#### Scenario: Request timing in debug mode

- **WHEN** a request completes
- **AND** debug logging is enabled
- **THEN** the log includes the request duration in milliseconds
- **AND** the duration is formatted for readability (e.g., "245ms")

#### Scenario: Slow request warning

- **WHEN** a request takes longer than the configured threshold
- **AND** logging is enabled
- **THEN** a warning is logged indicating a slow request
- **AND** the log includes the request URL and duration

**Default threshold:** 3 seconds

#### Scenario: Custom slow request threshold

- **WHEN** a developer configures a custom threshold via `withSlowRequestThreshold()`
- **THEN** warnings are logged for requests exceeding that duration
- **AND** setting the threshold to `null` disables slow request warnings

```dart
final dio = AcdcClientBuilder()
  .withSlowRequestThreshold(Duration(seconds: 5))
  .build();
```

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

**Example output (debug mode):**

```text
[2025-01-01 14:32:15.234] POST /api/users 201 (245ms) [req-12345]
Headers: {Content-Type: application/json, Authorization: [REDACTED]}
Body: {"username": "john", "email": "john@example.com"}
```

**Example output (info mode):**

```text
[2025-01-01 14:32:15.234] POST /api/users 201 (245ms)
```

**Example structured format (for custom loggers):**

```dart
{
  "timestamp": "2025-01-01T14:32:15.234Z",
  "requestId": "req-12345",
  "method": "POST",
  "url": "/api/users",
  "statusCode": 201,
  "duration": 245,
  "level": "info"
}
```

### Requirement: Custom Logger Support

The library SHALL allow developers to provide a custom logger implementation.

**Logger Interface:**

```dart
typedef AcdcLogger = void Function(
  String message,
  LogLevel level,
  Map<String, dynamic>? metadata,
);

enum LogLevel {
  debug,    // Detailed diagnostic information
  info,     // General informational messages
  warning,  // Warning messages (e.g., slow requests)
  error,    // Error messages (e.g., network failures)
  none,     // No HTTP request/response logging
}
```

#### Scenario: Custom logger injection

- **WHEN** a developer provides a custom logger via `withLogger()`
- **THEN** the custom logger is used instead of the default
- **AND** the custom logger receives all log events with message, level, and metadata
- **AND** the custom logger can implement platform-specific logging (e.g., Firebase Crashlytics)

```dart
final dio = AcdcClientBuilder()
  .withLogger((message, level, metadata) {
    // Send to custom analytics/logging service
    myCustomLogger.log(level, message, metadata);

    // Example: Send errors to Crashlytics
    if (level == LogLevel.error) {
      FirebaseCrashlytics.instance.log(message);
    }
  })
  .build();
```

#### Scenario: Non-blocking fire-and-forget logging

- **WHEN** the logger is invoked
- **THEN** the logger interface is synchronous (returns `void`, not `Future`)
- **AND** logging operations are dispatched asynchronously in the background
- **AND** HTTP request processing is never blocked waiting for logs to complete
- **AND** the default logger uses background mechanisms (isolates, queues, or buffering) for I/O operations

**Rationale:** The synchronous interface provides simplicity while background dispatch ensures zero performance impact.

#### Scenario: Custom logger performance expectations

- **WHEN** a custom logger is provided
- **THEN** the logger SHOULD complete quickly (ideally < 1ms)
- **AND** if the logger performs I/O or expensive operations, it MUST dispatch them asynchronously
- **AND** synchronous blocking in custom loggers violates the zero-impact principle

**Example of proper custom logger:**

```dart
final dio = AcdcClientBuilder()
  .withLogger((message, level, metadata) {
    // Fast: Dispatch async work without awaiting
    unawaited(analyticsService.logAsync(message, level, metadata));

    // Fast: Queue for background processing
    logQueue.add(LogEntry(message, level, metadata));

    // AVOID: Synchronous I/O - blocks request processing
    // file.writeAsStringSync(message); // ❌ DON'T DO THIS
  })
  .build();
```

### Requirement: Error Logging

The library SHALL log errors and exceptions that occur during HTTP requests.

#### Scenario: Network failure logging

- **WHEN** a network error occurs (connection timeout, no internet, DNS failure)
- **AND** logging is enabled (any level except `LogLevel.none`)
- **THEN** an error-level log is emitted
- **AND** the log includes the error type, message, and request details
- **AND** the log includes the stack trace in debug mode

**Example:**

```text
[ERROR] Network failure: POST /api/users
Error: SocketException: Failed to connect
Duration: 5000ms (timeout)
```

#### Scenario: HTTP error status logging

- **WHEN** a response has an error status code (4xx or 5xx)
- **AND** logging is enabled
- **THEN** a warning-level log is emitted for 4xx errors
- **AND** an error-level log is emitted for 5xx errors
- **AND** the log includes the status code, response body (if available), and URL

#### Scenario: Interceptor error logging

- **WHEN** an interceptor throws an exception
- **AND** logging is enabled
- **THEN** an error-level log is emitted
- **AND** the log identifies which interceptor failed
- **AND** the error does not suppress the original exception

#### Scenario: Retry attempt logging

- **WHEN** a request is retried (from the retry interceptor)
- **AND** debug or info logging is enabled
- **THEN** an info-level log is emitted for each retry attempt
- **AND** the log includes the attempt number and reason for retry

**Example:**

```text
[INFO] Retry attempt 2/3: POST /api/users
Reason: Network timeout (5000ms)
Next attempt in: 2000ms
```

#### Scenario: Request cancellation logging

- **WHEN** a request is cancelled via CancelToken
- **AND** logging is enabled
- **THEN** an info-level log is emitted
- **AND** the log includes which request was cancelled and when
- **AND** the log indicates if cancellation was manual or automatic (e.g., timeout)

**Example:**

```text
[INFO] Request cancelled: GET /api/users/123
Reason: Manual cancellation via CancelToken
Duration before cancel: 1234ms
```

#### Scenario: Timeout type differentiation

- **WHEN** a timeout occurs
- **AND** logging is enabled
- **THEN** the log specifies the timeout type (connection, send, or receive)
- **AND** the log includes the configured timeout value and actual duration

**Example:**

```text
[ERROR] Connection timeout: POST /api/users
Configured timeout: 5000ms
Actual duration: 5000ms
Timeout type: Connection establishment
```

#### Scenario: SSL/Certificate error logging

- **WHEN** an SSL handshake fails or certificate validation fails
- **AND** logging is enabled
- **THEN** an error-level log is emitted
- **AND** the log includes the certificate error type and domain
- **AND** the log includes security warnings in release mode

**Example:**

```text
[ERROR] SSL Certificate error: GET https://api.example.com/users
Error: Certificate has expired
Issuer: CN=Let's Encrypt
Expiry date: 2024-12-01
```

#### Scenario: Response parsing error logging

- **WHEN** response parsing or transformation fails (e.g., JSON decode error)
- **AND** logging is enabled
- **THEN** an error-level log is emitted
- **AND** the log includes the parsing error and the first 200 characters of the response
- **AND** sensitive data is still redacted

**Example:**

```text
[ERROR] Response parsing failed: GET /api/users/123
Error: FormatException: Unexpected character at position 45
Response preview: {"user": {"name": "John"...
Status: 200
```

### Requirement: Cross-Interceptor Logging

The library SHALL log events from other interceptors to provide a complete picture of request processing.

#### Scenario: Cache hit/miss logging

- **WHEN** a request is served from cache (cache hit)
- **AND** debug logging is enabled
- **THEN** an info-level log indicates the cache hit
- **AND** the log includes the cache key and age of cached data

**Example:**

```text
[INFO] Cache HIT: GET /api/users/123
Cache age: 45s / Max age: 300s
```

- **WHEN** a cache miss occurs
- **AND** debug logging is enabled
- **THEN** a debug-level log indicates the cache miss

#### Scenario: Authentication token refresh logging

- **WHEN** an authentication token is refreshed
- **AND** logging is enabled
- **THEN** an info-level log is emitted
- **AND** the log does not include the actual token value
- **AND** the log includes the reason for refresh (expired, missing, invalid)

**Example:**

```text
[INFO] Token refresh triggered
Reason: Token expired (exp: 2025-01-01 14:00:00)
Refresh successful: true
Duration: 234ms
```

#### Scenario: Request modification logging

- **WHEN** an interceptor modifies a request (adds headers, changes URL, etc.)
- **AND** debug logging is enabled
- **THEN** a debug-level log describes the modification
- **AND** the log identifies which interceptor made the change

**Example:**

```text
[DEBUG] Request modified by AuthInterceptor
Added headers: {Authorization: [REDACTED]}
```

#### Scenario: Cache write logging

- **WHEN** a response is successfully written to cache
- **AND** debug logging is enabled
- **THEN** a debug-level log is emitted
- **AND** the log includes the cache key, response size, and TTL

**Example:**

```text
[DEBUG] Cache WRITE: GET /api/users/123
Cache key: users_123_v1
Response size: 2.4 KB
TTL: 300s (expires: 2025-01-01 14:37:15)
```

#### Scenario: HTTP redirect logging

- **WHEN** a request follows an HTTP redirect (301, 302, 307, 308)
- **AND** logging is enabled
- **THEN** an info-level log is emitted for each redirect
- **AND** the log includes the redirect status code, original URL, and target URL
- **AND** a warning is logged if max redirects is approached or exceeded

**Example:**

```text
[INFO] HTTP Redirect: GET /old-endpoint
Status: 301 Moved Permanently
Redirect to: /new-endpoint
Redirect count: 1 / Max: 5
```

**Max redirects warning:**

```text
[WARNING] Max redirects exceeded: GET /infinite-loop
Redirect count: 5 / Max: 5
Last redirect to: /another-redirect
```

### Requirement: Request Validation and Warning Logging

The library SHALL log validation errors and warnings before requests are sent.

#### Scenario: Request validation error logging

- **WHEN** a request has validation errors (malformed URL, invalid headers, missing required fields)
- **AND** the request cannot be sent
- **THEN** an error-level log is emitted before throwing the exception
- **AND** the log includes the specific validation failure reason

**Example:**

```text
[ERROR] Request validation failed: POST (invalid URL)
Error: Invalid URL format - missing scheme
Provided: www.example.com/api/users
Expected format: https://www.example.com/api/users
```

#### Scenario: Large payload warning

- **WHEN** a request or response payload exceeds a threshold
- **AND** logging is enabled
- **THEN** a warning-level log is emitted
- **AND** the log includes the payload size and suggests optimization

**Default threshold:** 1 MB (1,048,576 bytes)

**Example:**

```text
[WARNING] Large request payload: POST /api/upload
Payload size: 5.2 MB
Suggestion: Consider using multipart upload or compression
```

```text
[WARNING] Large response received: GET /api/reports/full
Response size: 12.3 MB
Duration: 3456ms
Suggestion: Consider pagination or response filtering
```

#### Scenario: Custom large payload threshold

- **WHEN** a developer configures a custom threshold via `withLargePayloadThreshold()`
- **THEN** warnings are logged for payloads exceeding that size
- **AND** setting the threshold to `null` disables large payload warnings

```dart
final dio = AcdcClientBuilder()
  .withLargePayloadThreshold(5 * 1024 * 1024) // 5 MB
  .build();
```

#### Scenario: Successful request completion logging

- **WHEN** a request completes successfully (2xx status)
- **AND** debug logging is enabled
- **THEN** a debug-level log confirms the successful completion
- **AND** the log includes duration and status code

**Example:**

```text
[DEBUG] Request completed successfully: POST /api/users
Status: 201 Created
Duration: 234ms
Response size: 456 bytes
```

### Requirement: Logging Error Resilience

The library SHALL ensure that logging failures never disrupt application functionality or impact the user experience in any way. Logging MUST be completely transparent to users—failures SHALL NOT cause errors, crashes, performance degradation, or any user-visible effects.

#### Scenario: Logger exception handling

- **WHEN** a custom logger throws an exception
- **THEN** the exception is caught and silently ignored
- **AND** the request processing continues normally
- **AND** the application does not crash

#### Scenario: Fallback logging on custom logger failure

- **WHEN** a custom logger throws an exception
- **AND** the app is in debug mode
- **THEN** a fallback to `print()` or `debugPrint()` is used
- **AND** the fallback log includes a warning about the logger failure

**Example fallback output:**

```text
[WARNING] Custom logger failed: Exception: Failed to write to analytics
Original log: [INFO] POST /api/users 201 (245ms)
```

#### Scenario: Circular dependency prevention

- **WHEN** logging causes another HTTP request (e.g., logging to remote service)
- **THEN** the nested request is not logged
- **AND** infinite logging loops are prevented
- **AND** a circuit breaker or flag prevents re-entrant logging

#### Scenario: Performance safeguards

- **WHEN** logging operations take excessive time (> 100ms)
- **THEN** subsequent logs may be throttled or skipped
- **AND** a warning is emitted about slow logging performance
- **AND** request processing is not significantly delayed

#### Scenario: Zero user impact guarantee

- **WHEN** any logging operation fails (exception, timeout, I/O error, etc.)
- **THEN** the failure has zero user-visible impact
- **AND** no error messages are shown to the user
- **AND** no UI elements are affected
- **AND** no performance degradation is perceivable by the user
- **AND** the HTTP request completes exactly as if logging were disabled
- **AND** only developers (via debug logs) may be aware of the logging failure

**Critical principle:** Users should never know logging exists. Whether it succeeds or fails is completely invisible to them.

