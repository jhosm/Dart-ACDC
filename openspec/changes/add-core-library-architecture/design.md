# Design: Core Library Architecture

## Context

Dart-ACDC aims to provide a zero-config, opinionated HTTP client for Flutter mobile apps that integrates seamlessly with OpenAPI-generated code. The core challenge is balancing sensible defaults with configurability while maintaining a minimal API surface.

**Stakeholders:**
- Flutter mobile developers using OpenAPI-generated clients
- Teams wanting consistent API patterns across projects
- Developers unfamiliar with Dio ecosystem packages

**Constraints:**
- Must work with openapi-generator Dart templates
- Must support both Android and iOS
- Must minimize bundle size impact
- Must not introduce significant latency

## Goals / Non-Goals

### Goals

1. **Zero-Config Default**: Provide a working Dio instance with best practices enabled by default
2. **Progressive Disclosure**: Allow advanced configuration without requiring it
3. **OpenAPI Integration**: Seamlessly inject into openapi-generated client constructors
4. **Type Safety**: Leverage Dart's type system for compile-time safety
5. **Testability**: Enable easy mocking and testing of HTTP interactions

### Non-Goals

1. **Replacing Dio**: We wrap Dio, not replace it - users can still use Dio directly if needed
2. **UI Components**: No UI widgets or screens - purely HTTP client logic
3. **State Management**: No opinions on app-level state (BLoC, Provider, etc.)
4. **Custom Serialization**: Rely on openapi-generated serialization

## Decisions

### Decision 1: Builder Pattern for Configuration

**What**: Use a fluent builder pattern for optional configuration.

**Why**:
- Provides clear, chainable API for configuration
- Enables zero-config default (just call `build()`)
- Familiar pattern in Dart/Flutter ecosystem

**Example**:

```dart
final dio = AcdcClientBuilder()
  .withBaseUrl('https://api.example.com')
  .withTimeout(Duration(seconds: 30))
  .withLogging(LogLevel.debug)
  .build();
```

**Alternatives Considered**:
- Named parameters constructor - becomes unwieldy with many optional params
- Configuration object - requires creating config before client

### Decision 2: Interceptor Chain Architecture

**What**: Use Dio's interceptor mechanism for cross-cutting concerns.

**Why**:
- Dio's native interceptor support is robust and well-documented
- Enables modular, testable components
- Clear execution order (request → response → error)

**Interceptor Order** (request phase):
1. Logging interceptor (log outgoing request)
2. Auth interceptor (inject token)
3. Dio's built-in interceptors
4. Cache interceptor (check cache)

**Interceptor Order** (response phase):
1. Cache interceptor (store response)
2. Error interceptor (normalize errors)
3. Auth interceptor (refresh token on 401)
4. Logging interceptor (log response)

**Alternatives Considered**:
- Custom middleware system - unnecessary reinvention
- Decorator pattern - less idiomatic in Dart

### Decision 3: Factory Method for Dio Instance

**What**: `AcdcClientBuilder.build()` returns a configured `Dio` instance, not a wrapper.

**Why**:
- Direct compatibility with openapi-generated clients
- No additional abstraction layer
- Users can still access full Dio API if needed

**Trade-off**: We lose ability to add custom methods, but gain simplicity and compatibility.

**Alternatives Considered**:
- Custom wrapper class - breaks openapi-generator compatibility
- Extend Dio class - fragile, tightly coupled to Dio internals

### Decision 4: Exception Hierarchy

**What**: Define custom exception types that wrap DioException.

**Why**:
- Provides user-friendly error categorization
- Enables type-safe error handling
- Includes actionable error messages

**Exception Types**:
- `AcdcException` (base)
  - `AcdcNetworkException` - Network errors (no connection, timeout)
  - `AcdcAuthException` - Authentication errors (401, 403)
  - `AcdcServerException` - Server errors (5xx)
  - `AcdcClientException` - Client errors (4xx except 401)
  - `AcdcCacheException` - Cache-related errors

**Alternatives Considered**:
- Use DioException directly - loses user-friendly categorization
- Custom error codes - less type-safe than exceptions

### Decision 5: Environment-Aware Logging

**What**: Logging behavior changes based on environment (debug vs release).

**Why**:
- Debug: Pretty-print for developer readability
- Release: Minimal logging, redact sensitive data
- Performance: Avoid expensive logging in production

**Detection**: Use `kDebugMode` from Flutter foundation.

**Alternatives Considered**:
- Manual configuration - error-prone, developers might forget
- Build flags - less flexible, requires rebuild

### Decision 6: Token Storage Abstraction

**What**: Provide a `TokenProvider` interface for auth token management.

**Why**:
- Decouples token storage from HTTP client
- Enables platform-specific secure storage (Keychain, Keystore)
- Testable with mock implementations

**Interface**:

```dart
abstract class TokenProvider {
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<void> setTokens(String accessToken, String? refreshToken);
  Future<void> clearTokens();
}
```

**Alternatives Considered**:
- Callback functions - less structured, harder to test
- Built-in storage - couples HTTP client to storage mechanism

## Risks / Trade-offs

### Risk 1: Dio Version Compatibility

**Risk**: Breaking changes in Dio package could require updates.

**Mitigation**:
- Pin to specific Dio version range in pubspec.yaml
- Monitor Dio releases and test new versions
- Document supported Dio versions

### Risk 2: Interceptor Order Bugs

**Risk**: Incorrect interceptor ordering could cause subtle bugs.

**Mitigation**:
- Document interceptor order explicitly
- Write integration tests covering interceptor interactions
- Provide debug logging to show interceptor execution

### Risk 3: Over-Configuration

**Risk**: Adding too many configuration options defeats "zero-config" goal.

**Mitigation**:
- Start minimal, add options only when requested
- Keep 80% use cases working with zero config
- Document sensible defaults prominently

### Risk 4: OpenAPI Generator Changes

**Risk**: Future openapi-generator versions might expect different Dio configuration.

**Mitigation**:
- Test with generated code regularly
- Provide examples showing integration
- Document tested openapi-generator versions

## Migration Plan

Not applicable - this is the initial release. Future breaking changes will follow semantic versioning and provide migration guides.

## Open Questions

1. **Should we support multiple authentication schemes out of the box?**
   - Bearer tokens (MVP)
   - API keys (Future?)
   - OAuth flows (Future?)

   **Decision**: Start with Bearer tokens only. Add others based on demand.

2. **Should caching be enabled by default?**
   - Pro: Better performance, respects HTTP cache headers
   - Con: Might surprise developers, need clear cache invalidation

   **Decision**: Enable by default, document clearly. Provide easy opt-out.

3. **Should we include retry logic in MVP?**
   - Pro: Improves resilience
   - Con: Adds complexity, need configuration for max retries

   **Decision**: Defer to V1. MVP focuses on core features.

4. **What's the minimum Dart SDK version?**
   - Need to support null safety (Dart 2.12+)
   - Check Flutter stable channel requirements

   **Decision**: Target Dart 3.0+ and Flutter 3.10+ (current stable as of 2024).
