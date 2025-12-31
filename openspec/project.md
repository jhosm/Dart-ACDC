# Project Context

## Purpose

**Dart-ACDC** (API Client with Dio and Conventions) is an opinionated Dart/Flutter library that enforces REST API consumption best practices for mobile applications. It provides a batteries-included wrapper around Dio and complementary packages, eliminating the need for developers to research, choose, and configure multiple packages.

**Goals:**

- Provide a zero-config REST API client that follows industry best practices
- Seamless integration with OpenAPI-generated Dart clients (via openapi-generator)
- Abstract away the complexity of HTTP client configuration, interceptors, error handling, retry logic, caching, and logging
- Enable developers to go from OpenAPI spec to working API client with minimal boilerplate

**Target Users:**

- Mobile developers building Flutter applications
- Teams wanting consistent API consumption patterns across projects
- Developers unfamiliar with the Dart/Flutter HTTP client ecosystem

## Tech Stack

### Primary Technologies

- **Dart** - Programming language
- **Flutter** - Mobile framework (target platform)
- **Dio** - Core HTTP client library
- **openapi-generator** - Code generation from OpenAPI/Swagger specs

### Key Dependencies (Dio Ecosystem)

- `dio` - HTTP client
- `dio_cache_interceptor` - Response caching
- `pretty_dio_logger` - Request/response logging
- `dio_smart_retry` - Automatic retry logic
- Additional interceptor packages as needed

### Development Tools

- `dart test` - Testing framework
- `dart analyze` - Static analysis
- `dart format` - Code formatting

## Project Conventions

### Code Style

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) style guidelines
- Use `dart format` for consistent formatting
- Apply `dart analyze` with strict linting rules
- Prefer explicit types over `var` in public APIs
- Use meaningful variable and function names (avoid abbreviations)

### Architecture Patterns

- **Builder Pattern**: For configuring the HTTP client
- **Interceptor Chain**: For modular request/response processing
- **Factory Pattern**: For creating pre-configured Dio instances
- **Adapter Pattern**: For integrating with openapi-generated clients
- Keep the API surface small and focused - minimize required configuration

### Testing Strategy

- **Unit Tests**: All core logic, interceptors, and builders
- **Integration Tests**: End-to-end API client scenarios (with mocked responses)
- **Code Coverage**: Target 80%+ coverage for core library code
- **Example Tests**: Ensure example code in documentation stays working
- Use mocking for HTTP responses (dio_mock_adapter or similar)

### Git Workflow

- **Main Branch**: `main` (protected, requires PR)
- **Feature Branches**: `feature/description` or `add-description`
- **Commit Convention**: Conventional Commits (feat:, fix:, docs:, test:, refactor:)
- **PR Process**: All changes via pull request with code review
- **CI/CD**: Automated tests and linting on all PRs

## Domain Context

### REST API Best Practices (Enforced by Library)

#### 1. Security & Authentication

- **OAuth 2.1/OIDC with PKCE** - Prevent authorization code interception
- **Token Management** - Short-lived access tokens + secure refresh tokens
- **Auto-Refresh** - Intercept 401s and automatically refresh tokens
- **Secure Storage** - Use platform-specific secure storage (iOS Keychain, Android Keystore)
- **HTTPS/TLS 1.2+ only** - No plain HTTP allowed
- **Certificate validation** - Strict certificate checking
- **Optional certificate pinning** - For high-security apps

#### 2. Retry Logic & Resilience

- **Automatic retry** - For transient failures (network errors, 5xx status codes)
- **Exponential backoff** - Increasing delay between retries
- **Jitter** - Random delay to prevent thundering herd
- **Retry-After header respect** - Honor 429 (Too Many Requests) retry guidance
- **Configurable retry policies** - Max attempts, which errors to retry
- **Request cancellation** - Cancel in-flight requests
- **Request deduplication** - Prevent duplicate concurrent requests
- **Timeout configuration** - Connection, read, and write timeouts

#### 3. Caching

- **HTTP cache headers** - Respect Cache-Control, ETag, Last-Modified
- **Stale-While-Revalidate** - Serve cached data immediately, update in background
- **Client-side caching** - Store frequently accessed data locally
- **Cache invalidation** - Clear cache on logout, version change, manual refresh
- **Configurable cache policies** - TTL, max size, cache keys
- **In-memory cache** - Fast access for session data
- **Persistent cache** - Disk storage for offline support
- **Secure caching** - Don't cache sensitive data (PII, tokens)

#### 4. Error Handling

- **HTTP status code mapping** - 4xx client errors, 5xx server errors
- **Custom exception types** - NetworkError, AuthError, ServerError, ValidationError
- **Error interceptors** - Centralized error handling
- **User-friendly error messages** - Convert technical errors to actionable messages
- **Error logging** - Track errors for debugging
- **Network unavailable detection** - Detect offline state, show offline UI
- **Timeout handling** - Clear messaging when requests timeout

#### 5. Logging & Debugging

- **Development logging** - Pretty-print requests/responses with pretty_dio_logger
- **Production logging** - Minimal logging, redact sensitive data
- **Structured logs** - Include request ID, timestamp, duration, status code
- **Redaction** - Never log auth tokens, passwords, PII
- **Request duration tracking** - Performance monitoring
- **Response size monitoring** - Track payload sizes

#### 6. Performance Optimization

- **HTTP/2 or HTTP/3** - Multiplexing, reduced latency
- **Connection pooling** - Reuse connections
- **Keep-alive** - Persistent connections
- **Request compression** - gzip/brotli for request bodies
- **Response compression** - Automatic decompression
- **Pagination support** - Limit response size, lazy load

#### 7. Interceptors & Middleware

- **Request Interceptors** - Auth token injection, custom headers, request transformation
- **Response Interceptors** - Token refresh on 401, response transformation, error normalization
- **Configurable chain** - Add/remove interceptors as needed

#### 8. Mobile-Specific Concerns

- **Offline detection** - Check network connectivity
- **Background operations** - Don't block UI thread
- **Progress tracking** - Upload/download progress callbacks
- **Network adaptability** - Adjust timeouts for slow connections
- **Data saving mode** - Reduce payload size on metered connections

#### 9. Serialization

- **Automatic JSON encoding/decoding**
- **Type-safe models** - Use generated models from OpenAPI
- **Null safety** - Handle missing/null fields gracefully
- **Error handling** - Catch serialization errors

### Feature Priorities

#### Must-Have (MVP)

1. Error handling (status codes, exceptions)
2. Token auto-refresh on 401
3. Timeout configuration
4. Basic logging (dev/prod modes)
5. Auth token injection (Bearer tokens)
6. HTTP caching
7. Request/response interceptors

#### Should-Have (V1)

1. Certificate pinning
2. Request cancellation
3. Offline detection
4. Stale-while-revalidate caching
5. Request deduplication
6. Progress tracking

#### Nice-to-Have (Future)

1. Retry logic with exponential backoff
2. Request queue for offline
3. Network quality adaptation
4. HTTP/3 support

### OpenAPI Integration

- Library should provide a configured Dio instance to openapi-generated clients
- Generated clients use `openapi-generator-cli` with Dart templates
- Developer workflow: OpenAPI YAML → `openapi-generator` → Generated client → ACDC Dio instance

## Important Constraints

### Technical Constraints

- Must be compatible with Flutter stable channel
- Support both Android and iOS platforms
- Minimize additional dependencies (only proven, maintained packages)
- Maintain backward compatibility within major versions
- Keep bundle size impact minimal

### Developer Experience Constraints

- **Zero Config Default**: Should work out-of-the-box with sensible defaults
- **Progressive Disclosure**: Advanced configuration available but not required
- **Clear Error Messages**: Helpful error messages with actionable guidance
- **Minimal Learning Curve**: Developers should understand basics in <10 minutes

### Performance Constraints

- HTTP operations should not introduce significant latency
- Caching should improve perceived performance
- Memory footprint should be minimal
- No blocking operations on the main UI thread

## External Dependencies

### Core Dependencies

- **Dio**: HTTP client foundation - <https://pub.dev/packages/dio>
- **openapi-generator**: Code generation tool - <https://openapi-generator.tech/>

### Interceptor Packages (To Evaluate)

- `dio_cache_interceptor` - Response caching
- `pretty_dio_logger` - Development logging
- `dio_smart_retry` - Retry logic with backoff
- Consider: custom interceptors for auth, error normalization

### Development Dependencies

- Dart SDK (latest stable)
- Flutter SDK (latest stable)
- `dart test` - Testing
- `mockito` or `mocktail` - Mocking for tests

## Documentation Requirements

- **README.md**: Quick start, installation, basic usage
- **API Documentation**: Dartdoc comments on all public APIs
- **Examples**: Working example projects showing common patterns
- **Migration Guides**: For breaking changes between versions
- **Architecture Decision Records**: Document key technical decisions
