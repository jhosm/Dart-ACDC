# HTTP Client Specification

## ADDED Requirements

### Requirement: Client Builder

The library SHALL provide an `AcdcClientBuilder` class that creates pre-configured Dio instances using the builder pattern.

#### Scenario: Zero-config client creation

- **WHEN** a developer calls `AcdcClientBuilder().build()`
- **THEN** a Dio instance is returned with all default interceptors configured
- **AND** sensible default timeout values are set
- **AND** HTTP caching is enabled by default

#### Scenario: Custom base URL configuration

- **WHEN** a developer calls `AcdcClientBuilder().withBaseUrl('https://api.example.com').build()`
- **THEN** the returned Dio instance uses the specified base URL for all requests

#### Scenario: Custom timeout configuration

- **WHEN** a developer calls `AcdcClientBuilder().withTimeout(Duration(seconds: 30)).build()`
- **THEN** the returned Dio instance uses 30-second timeouts for connection, send, and receive operations

### Requirement: Default Timeouts

The library SHALL configure default timeout values that prevent hanging requests while accommodating slow mobile networks.

#### Scenario: Default timeout values

- **WHEN** a Dio instance is created with zero configuration
- **THEN** the connection timeout is set to 30 seconds
- **AND** the receive timeout is set to 30 seconds
- **AND** the send timeout is set to 30 seconds

### Requirement: Interceptor Chain Configuration

The library SHALL configure Dio interceptors in a specific order to ensure correct behavior across all features.

#### Scenario: Request interceptor order

- **WHEN** a request is made through the configured Dio instance
- **THEN** interceptors execute in this order:
  1. Logging interceptor (logs outgoing request)
  2. Auth interceptor (injects authentication token)
  3. Cache interceptor (checks for cached response)

#### Scenario: Response interceptor order

- **WHEN** a response is received
- **THEN** interceptors execute in this order:
  1. Cache interceptor (stores response in cache)
  2. Error interceptor (normalizes errors)
  3. Auth interceptor (handles 401 with token refresh)
  4. Logging interceptor (logs response)

### Requirement: OpenAPI Generator Compatibility

The library SHALL return a standard Dio instance that is compatible with openapi-generator Dart clients without modification.

#### Scenario: Integration with generated API client

- **WHEN** a developer passes the configured Dio instance to an openapi-generated client constructor
- **THEN** the client accepts the Dio instance without errors
- **AND** all interceptors function correctly with generated API calls

### Requirement: Builder Method Chaining

The library SHALL support fluent method chaining for all builder configuration methods.

#### Scenario: Multiple configuration options

- **WHEN** a developer chains multiple configuration methods
- **THEN** each method returns the builder instance
- **AND** all configurations are applied to the final Dio instance

```dart
final dio = AcdcClientBuilder()
  .withBaseUrl('https://api.example.com')
  .withTimeout(Duration(seconds: 45))
  .withLogging(LogLevel.debug)
  .build();
```
