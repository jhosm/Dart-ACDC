# HTTP Client Specification

## ADDED Requirements

### Requirement: Client Builder

The library SHALL provide an immutable `AcdcClientBuilder` class that creates pre-configured **standard Dio instances** (not wrapper classes) using the builder pattern.

**Note:** The builder uses an immutable design pattern. Each configuration method returns a new builder instance with the updated configuration, preserving the original builder. The builder returns a standard `Dio` instance to ensure full compatibility with openapi-generator and the Dio ecosystem.

#### Scenario: Zero-config client creation

- **WHEN** a developer calls `AcdcClientBuilder().build()`
- **THEN** a Dio instance is returned with all default interceptors configured
- **AND** sensible default timeout values are set
- **AND** HTTP caching is enabled by default (see [Caching Specification](../caching/spec.md) for details)

#### Scenario: Custom base URL configuration

- **WHEN** a developer calls `AcdcClientBuilder().withBaseUrl('https://api.example.com').build()`
- **THEN** the returned Dio instance uses the specified base URL for all requests

#### Scenario: Custom timeout configuration

- **WHEN** a developer calls `AcdcClientBuilder().withTimeout(Duration(seconds: 30)).build()`
- **THEN** the returned Dio instance uses 30-second timeouts for connection, send, and receive operations

#### Scenario: Builder immutability and build() reusability

- **WHEN** a developer calls `build()` on a builder instance
- **THEN** a new Dio instance is created and returned
- **AND** the builder instance can be reused to create additional Dio instances
- **AND** calling `build()` multiple times on the same builder creates independent Dio instances
- **AND** each Dio instance has its own interceptor chain and configuration
- **AND** modifications to configuration methods return new builder instances (immutable pattern)

```dart
// Reusing builder to create multiple clients
final builder = AcdcClientBuilder()
  .withBaseUrl('https://api.example.com');

final dio1 = builder.build();  // First instance
final dio2 = builder.build();  // Second instance, independent of first

// Immutable builder pattern
final baseBuilder = AcdcClientBuilder();
final prodBuilder = baseBuilder.withBaseUrl('https://api.prod.com');
final devBuilder = baseBuilder.withBaseUrl('https://api.dev.com');
// baseBuilder remains unchanged
```

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
  3. Dio's built-in interceptors (transformation, adapters)
  4. Cache interceptor (checks for cached response)

#### Scenario: Response interceptor order

- **WHEN** a response is received
- **THEN** interceptors execute in this order:
  1. Cache interceptor (stores response in cache)
  2. Auth interceptor (handles 401 with token refresh)
  3. Error interceptor (normalizes errors after auth retry)
  4. Logging interceptor (logs response)
- **AND** this order ensures 401 responses are handled by auth interceptor before error conversion
- **AND** the error interceptor only converts errors that auth interceptor cannot handle
- **AND** cached responses bypass auth token refresh attempts (see [Authentication Specification](../authentication/spec.md) and [Caching Specification](../caching/spec.md) for rationale)

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
  .withLogLevel(LogLevel.debug)  // See Logging Specification
  .build();
```

### Requirement: Feature Opt-Out

The library SHALL allow developers to disable default features when not needed.

#### Scenario: Disable caching

- **WHEN** a developer calls `AcdcClientBuilder().disableCache().build()`
- **THEN** the cache interceptor is NOT added to the interceptor chain
- **AND** all requests bypass caching
- **AND** no cache storage is initialized

#### Scenario: Disable authentication

- **WHEN** a developer calls `AcdcClientBuilder().build()` without configuring a TokenProvider
- **THEN** the auth interceptor is NOT added to the interceptor chain
- **AND** no Authorization headers are injected
- **AND** 401 responses are treated as regular client errors

#### Scenario: Disable logging

- **WHEN** a developer calls `AcdcClientBuilder().withLogLevel(LogLevel.none).build()`
- **THEN** the logging interceptor is NOT added to the interceptor chain
- **AND** no HTTP request/response logging occurs
- **AND** error and warning logs may still be emitted
- **AND** this is documented in the [Logging Specification](../logging/spec.md)

### Requirement: Custom Interceptor Support

The library SHALL allow developers to add custom interceptors while maintaining correct chain order.

#### Scenario: Add custom interceptor

- **WHEN** a developer calls `AcdcClientBuilder().withInterceptor(customInterceptor).build()`
- **THEN** the custom interceptor is added to the interceptor chain
- **AND** the custom interceptor executes after built-in interceptors
- **AND** developers can add multiple custom interceptors

#### Scenario: Custom interceptor ordering

- **WHEN** multiple custom interceptors are added
- **THEN** they execute in the order they were added
- **AND** built-in interceptors (auth, cache, error, logging) maintain their relative order
- **AND** custom interceptors execute after all built-in interceptors

```dart
final dio = AcdcClientBuilder()
  .withInterceptor(customInterceptor1)
  .withInterceptor(customInterceptor2)
  .build();
// Chain: [Logging, Auth, Cache, customInterceptor1, customInterceptor2]
```

#### Scenario: Custom interceptor with specific position

- **WHEN** a developer needs precise control over interceptor ordering
- **THEN** they can access the Dio instance after build and manipulate interceptors directly
- **AND** this is an advanced use case for specialized requirements

### Requirement: Builder Validation

The library SHALL validate builder configurations and provide clear error messages for invalid inputs.

#### Scenario: Invalid timeout values

- **WHEN** a developer calls `AcdcClientBuilder().withTimeout(Duration(seconds: -1))`
- **THEN** an `ArgumentError` is thrown immediately
- **AND** the error message indicates "Timeout duration must be positive"
- **AND** the builder does not accept negative or zero timeout values

#### Scenario: Invalid base URL

- **WHEN** a developer calls `AcdcClientBuilder().withBaseUrl('not-a-valid-url')`
- **THEN** an `ArgumentError` is thrown when `.build()` is called
- **AND** the error message indicates the URL format is invalid
- **AND** the error message suggests the correct format (e.g., "https://api.example.com")

#### Scenario: Null values rejected

- **WHEN** a developer passes null to a required configuration parameter
- **THEN** an `ArgumentError` is thrown immediately
- **AND** the error message indicates which parameter was null
- **AND** the builder enforces non-null requirements at compile time where possible

#### Scenario: Conflicting configurations

- **WHEN** a developer provides conflicting configurations
- **THEN** the last configuration wins
- **AND** a warning may be logged in debug mode about the override

```dart
final dio = AcdcClientBuilder()
  .withTimeout(Duration(seconds: 30))
  .withTimeout(Duration(seconds: 60))  // This value is used
  .build();
```

### Requirement: Integration with Other Specifications

The library SHALL integrate seamlessly with authentication, caching, error handling, and logging as specified in their respective specifications.

#### Cross-References

- **Authentication**: Token injection and refresh handled by [Authentication Specification](../authentication/spec.md)
- **Caching**: HTTP caching behavior defined in [Caching Specification](../caching/spec.md)
- **Error Handling**: Error normalization and exception types defined in [Error Handling Specification](../error-handling/spec.md)
- **Logging**: Request/response logging configured via [Logging Specification](../logging/spec.md)

#### Scenario: Cohesive feature integration

- **WHEN** all features are enabled (auth, caching, error handling, logging)
- **THEN** they work together without conflicts
- **AND** the interceptor chain order ensures correct behavior
- **AND** each feature's specification defines its specific behavior

### Requirement: Authentication Manager Access

The library SHALL provide access to authentication management functionality via a Dart extension on the returned Dio instance.

#### Scenario: Access auth manager

- **WHEN** a developer configures authentication via `withTokenProvider()`
- **THEN** the built Dio instance includes an auth manager accessible via `dio.auth`
- **AND** this provides methods for logout, forced token refresh, and cache management
- **AND** the auth manager is fully documented in the [Authentication Specification](../authentication/spec.md)
- **AND** the extension maintains OpenAPI generator compatibility (standard Dio instance)

#### Scenario: Auth manager methods

- **WHEN** the auth manager is accessed via `dio.auth`
- **THEN** it provides these methods:
  - `Future<void> logout()` - Revoke tokens server-side and clear local storage
  - `Future<void> refreshNow()` - Force immediate token refresh
  - `Future<void> clearCache()` - Clear all cached HTTP responses
- **AND** each method's behavior is defined in the [Authentication Specification](../authentication/spec.md) and [Caching Specification](../caching/spec.md)

#### Scenario: No auth configured

- **WHEN** no TokenProvider is configured
- **AND** a developer accesses `dio.auth`
- **THEN** the auth manager is still available but methods throw informative errors
- **AND** error messages indicate "Authentication not configured. Use withTokenProvider() to enable."

### Out of Scope

The following features are intentionally **not** part of this specification and will be addressed separately:

- **Retry Logic**: Automatic retry on transient failures (network errors, 5xx responses) will be handled in a future specification
- **Request/Response Transformation**: Custom data transformation beyond standard JSON encoding/decoding
- **Certificate Pinning**: SSL certificate pinning for enhanced security
- **Proxy Configuration**: HTTP proxy support for corporate networks
- **Connection Pooling**: Advanced connection pool management settings
