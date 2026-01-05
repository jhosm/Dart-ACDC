# error-handling Specification

## Purpose
TBD - created by archiving change add-core-library-architecture. Update Purpose after archive.
## Requirements
### Requirement: Exception Hierarchy

The library SHALL define a custom exception hierarchy that categorizes HTTP errors into developer-friendly types with rich debugging context.

#### Scenario: Base exception class structure

- **WHEN** any ACDC exception is created
- **THEN** it is a subtype of `AcdcException` which extends `DioException`
- **AND** exposes these properties:
  - `String message` - Developer-focused error description with context
  - `DioException originalException` - Original Dio error for low-level debugging
  - `int? statusCode` - HTTP status code (null for network errors)
  - `dynamic responseData` - Response body (truncated if > 1KB, null if unavailable)
  - `String? requestUrl` - The URL that failed (redacted for security if contains tokens)
  - `StackTrace stackTrace` - Full stack trace for debugging
- **AND** provides a `toString()` method with formatted output including all context

#### Scenario: Exception type categorization

- **WHEN** different HTTP errors occur
- **THEN** they are mapped to appropriate exception types:

| Error Category | Status Codes / Conditions | Exception Type | Use Case |
|----------------|---------------------------|----------------|----------|
| Network errors | No connection, DNS failure, timeouts | `AcdcNetworkException` | Connectivity issues |
| Auth errors | 401, 403 | `AcdcAuthException` | Authentication/authorization failures |
| Server errors | 500, 502, 503, 504 | `AcdcServerException` | Backend issues |
| Client errors | 400, 404, 422, 429, etc. | `AcdcClientException` | Invalid requests |
| Cache errors | Cache read/write failures | `AcdcCacheException` | Storage issues |

### Requirement: HTTP Status Code Mapping

The library SHALL map HTTP status codes to specific exception types based on error category with detailed context.

#### Scenario: Status code to exception mapping

- **WHEN** a response is received with a status code
- **THEN** it is categorized as follows:

| Status Code Range | Exception Type | Example Message Template |
|-------------------|----------------|--------------------------|
| 400, 404, 422, 429 (4xx except 401/403) | `AcdcClientException` | "Client error {statusCode}: {reason}" |
| 401, 403 | `AcdcAuthException` | "Authentication failed: {statusCode} {reason}" |
| 500, 502, 503, 504 (5xx) | `AcdcServerException` | "Server error {statusCode}. Please try again later." |

- **AND** the exception includes the full response body (truncated to 1KB)
- **AND** the exception includes the request URL (without sensitive query params)

#### Scenario: Response body truncation

- **WHEN** a response body exceeds 1KB
- **THEN** only the first 1KB is included in `responseData`
- **AND** a truncation indicator is appended: `"... [truncated, {actualSize}KB total]"`
- **AND** developers can access the full body via `originalException.response.data`

#### Scenario: Special status code handling

- **WHEN** a response has status code 429 (Too Many Requests)
- **THEN** an `AcdcClientException` is thrown
- **AND** the message includes "Rate limit exceeded"
- **AND** if `Retry-After` header is present, includes "Retry after {seconds} seconds"

### Requirement: Network Error Handling

The library SHALL detect and categorize network connectivity issues separately from HTTP errors with actionable guidance.

#### Scenario: Network error categorization

- **WHEN** network errors occur
- **THEN** they are mapped to `AcdcNetworkException` with appropriate error types:

| Dio Error Type | Network Error Type | Message Template |
|----------------|-------------------|------------------|
| `DioExceptionType.connectionTimeout` | `NetworkErrorType.timeout` | "Request timed out after {duration}s. Check your connection." |
| `DioExceptionType.receiveTimeout` | `NetworkErrorType.timeout` | "Response timed out after {duration}s. Check your connection." |
| `DioExceptionType.sendTimeout` | `NetworkErrorType.timeout` | "Upload timed out after {duration}s. Check your connection." |
| `DioExceptionType.connectionError` | `NetworkErrorType.noConnection` | "No internet connection. Please check your network." |
| DNS resolution failure | `NetworkErrorType.noConnection` | "Cannot reach server. Check your connection or try again later." |

- **AND** all network errors include the request URL
- **AND** all network errors suggest user-actionable recovery steps

#### Scenario: Network error properties

- **WHEN** a `AcdcNetworkException` is created
- **THEN** it includes an additional property:
  - `NetworkErrorType errorType` - Enum value (`timeout`, `noConnection`)
- **AND** `statusCode` is always null (not an HTTP error)

### Requirement: Error Message Design

The library SHALL provide error messages that balance developer debugging needs with security and clarity.

#### Scenario: Error message audience and format

- **WHEN** any exception message is generated
- **THEN** the message is developer-focused (not end-user UI text)
- **AND** includes technical context (status code, URL, error category)
- **AND** suggests concrete debugging or recovery actions
- **AND** applications SHOULD translate messages to user-friendly UI text using custom error handling

#### Scenario: Error message security

- **WHEN** including request URLs in error messages
- **THEN** sensitive query parameters are redacted (e.g., `?token=abc` → `?token=[REDACTED]`)
- **AND** Authorization headers are never included in messages
- **AND** response bodies containing credentials or tokens are sanitized

#### Scenario: Error message examples

- **WHEN** specific errors occur
- **THEN** messages follow these patterns:

| Error Type | Example Message |
|------------|-----------------|
| 400 Bad Request | "Client error 400: Invalid request. Check request parameters. Response: {body}" |
| 401 Unauthorized | "Authentication failed: 401 Unauthorized. Token may be expired." |
| 404 Not Found | "Client error 404: Resource not found at {url}" |
| 500 Internal Server Error | "Server error 500. Please try again later." |
| Connection timeout | "Request timed out after 30s. Check your connection." |
| No internet | "No internet connection. Please check your network." |

### Requirement: Error Interceptor

The library SHALL provide an error interceptor that automatically converts DioException to ACDC exception types with proper integration in the interceptor chain.

#### Scenario: Automatic error conversion

- **WHEN** Dio throws a DioException during a request
- **THEN** the error interceptor catches it
- **AND** converts it to the appropriate AcdcException subtype based on error type
- **AND** rethrows the ACDC exception to the caller

#### Scenario: Error interceptor chain position

- **WHEN** the error interceptor processes errors
- **THEN** it MUST NOT convert 401/403 responses that can be handled by auth interceptor
- **AND** authentication errors are only converted AFTER auth interceptor decides not to retry
- **AND** this allows token refresh to happen before error conversion
- **AND** if auth interceptor is not configured, 401/403 are immediately converted to `AcdcAuthException`

#### Scenario: Error interceptor bypass for handled errors

- **WHEN** a 401 response is received
- **AND** auth interceptor is configured and successfully refreshes the token
- **AND** the retried request succeeds
- **THEN** no exception is thrown (transparent recovery)
- **AND** error interceptor never sees the 401 (already handled)

### Requirement: Edge Case Handling

The library SHALL handle malformed responses, redirects, and non-standard status codes gracefully.

#### Scenario: Malformed response handling

- **WHEN** a response cannot be parsed (invalid JSON, corrupted data)
- **THEN** an `AcdcClientException` is thrown
- **AND** the message indicates "Invalid response format from server"
- **AND** the raw response body is included (truncated to 1KB)

#### Scenario: 3xx redirect handling

- **WHEN** a redirect response (301, 302, 307, 308) is received
- **AND** Dio's automatic redirect following is disabled
- **THEN** an `AcdcClientException` is thrown
- **AND** the message indicates "Unexpected redirect to {location}"
- **WHEN** automatic redirects are enabled (default)
- **THEN** no exception is thrown (Dio handles transparently)

#### Scenario: Non-standard status codes

- **WHEN** a non-standard status code is received (e.g., 418, 451, 599)
- **THEN** it is categorized by status code range:
  - 4xx → `AcdcClientException`
  - 5xx → `AcdcServerException`
  - Other → `AcdcClientException` (fallback)
- **AND** the message includes "Unexpected status code {code}: {reason}"

### Requirement: Cache Error Handling

The library SHALL handle cache storage failures transparently without disrupting request processing.

#### Scenario: Cache error categorization

- **WHEN** cache operations fail (read, write, delete)
- **THEN** an `AcdcCacheException` is created (but not thrown to request callers)
- **AND** the error is logged for debugging
- **AND** the request continues normally (cache miss or skip cache write)

#### Scenario: Cache error properties

- **WHEN** a `AcdcCacheException` is created
- **THEN** it includes an additional property:
  - `CacheOperation operation` - Enum value (`read`, `write`, `delete`, `clear`)
- **AND** `statusCode` is always null (not an HTTP error)
- **AND** the message indicates the cache operation that failed

### Requirement: Developer Experience

The library SHALL provide utilities for testing and debugging exception handling.

#### Scenario: Exception equality for testing

- **WHEN** comparing two AcdcException instances in tests
- **THEN** they are equal if:
  - Same exception type
  - Same status code
  - Same error message
- **AND** this enables easy assertion in unit tests

#### Scenario: Exception serialization

- **WHEN** an exception needs to be logged or reported
- **THEN** `toString()` provides a formatted multi-line output:
  ```
  AcdcClientException: Client error 400: Invalid request
    Status Code: 400
    URL: https://api.example.com/users
    Response: {"error": "Missing required field 'email'"}
    Stack Trace: [...]
  ```
- **AND** all exceptions implement a `toMap()` method for structured logging:
  ```dart
  {
    'type': 'AcdcClientException',
    'message': 'Client error 400: Invalid request',
    'statusCode': 400,
    'url': 'https://api.example.com/users',
    'responseData': {...}
  }
  ```

