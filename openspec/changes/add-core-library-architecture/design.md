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
2. Auth interceptor (refresh token on 401)
3. Error interceptor (normalize errors after auth retry)
4. Logging interceptor (log response)

**Rationale**: Auth interceptor must run before error interceptor to enable transparent token refresh. The error interceptor only converts errors that the auth interceptor cannot handle.

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

**What**: Define custom exception types that extend DioException while preserving the original exception.

**Why**:

- Provides developer-friendly error categorization
- Enables type-safe error handling
- Includes actionable error messages for debugging
- Backward compatible: code catching `DioException` still works
- Preserves original exception via `originalException` property for low-level debugging

**Exception Types**:

- `AcdcException extends DioException` (base)
  - `AcdcNetworkException` - Network errors (no connection, timeout)
  - `AcdcAuthException` - Authentication errors (401, 403)
  - `AcdcServerException` - Server errors (5xx)
  - `AcdcClientException` - Client errors (4xx except 401)
  - `AcdcCacheException` - Cache-related errors

**Implementation Pattern**:

```dart
class AcdcException extends DioException {
  final DioException originalException; // Preserved for low-level debugging
  final int? statusCode;
  final dynamic responseData; // Truncated to 1KB for safety
  final String? requestUrl; // Redacted if contains sensitive params
  // ... constructor and methods
}
```

**Error Message Philosophy**:

- Messages are developer-focused (include technical context, status codes, URLs)
- Applications should translate these to user-friendly UI messages based on their UX needs
- This separation enables better i18n/localization at the app layer

**Alternatives Considered**:

- Use DioException directly - loses developer-friendly categorization
- Custom error codes - less type-safe than exceptions
- Pure wrapping (composition only) - breaks backward compatibility with `DioException` catchers

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

**What**: Provide a `TokenProvider` interface for auth token management with expiry tracking.

**Why**:
- Decouples token storage from HTTP client
- Enables platform-specific secure storage (Keychain, Keystore)
- Testable with mock implementations
- Supports proactive token refresh via expiry tracking

**Interface**:

```dart
abstract class TokenProvider {
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<DateTime?> getAccessTokenExpiry();
  Future<DateTime?> getRefreshTokenExpiry();
  Future<void> setTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? accessExpiry,
    DateTime? refreshExpiry,
  });
  Future<void> clearTokens();
}
```

**Key Points**:

- Provider stores tokens without validating expiry
- Library's auth interceptor checks expiry before using tokens
- Enables both proactive (before expiry) and reactive (on 401) refresh

**Alternatives Considered**:

- Callback functions - less structured, harder to test
- Built-in storage - couples HTTP client to storage mechanism
- Provider validates expiry - couples validation to storage, harder to test

### Decision 7: Auth Extension for Logout

**What**: Provide logout functionality via a Dart extension on the Dio instance.

**Why**:

- Keeps the main Dio API clean (returns standard Dio instance)
- Enables logout with token revocation: `dio.auth.logout()`
- Provides access to auth manager: `dio.auth.clearCache()`, `dio.auth.refreshNow()`
- Maintains OpenAPI generator compatibility

**Implementation**:

```dart
extension AcdcAuth on Dio {
  AcdcAuthManager get auth => // retrieve auth manager from Dio options
}

class AcdcAuthManager {
  Future<void> logout(); // Revoke tokens + clear locally
  Future<void> refreshNow(); // Force refresh
  Future<void> clearCache(); // Clear cached responses
}
```

**Trade-off**: Extension methods aren't discovered as easily as instance methods, but this maintains compatibility with openapi-generated clients.

**Alternatives Considered**:

- Return custom wrapper class - breaks openapi-generator compatibility
- Global singleton manager - hard to test, breaks with multiple Dio instances
- Separate manager parameter - extra parameter burden on developers

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
