# Implementation Tasks

## 1. Project Setup

- [ ] 1.1 Create `pubspec.yaml` with package metadata and dependencies
- [ ] 1.2 Create `analysis_options.yaml` with strict linting rules
- [ ] 1.3 Create directory structure (`lib/`, `lib/src/`, `test/`)
- [ ] 1.4 Create `.gitignore` for Dart/Flutter projects
- [ ] 1.5 Create `README.md` with basic project description
- [ ] 1.6 Create `LICENSE` file (choose license: MIT, Apache 2.0, etc.)
- [ ] 1.7 Create `CHANGELOG.md` for version tracking

## 2. Core Types and Interfaces

- [ ] 2.1 Define `TokenProvider` interface in `lib/src/auth/token_provider.dart`
- [ ] 2.2 Define custom exception hierarchy in `lib/src/exceptions/`
  - [ ] 2.2.1 `AcdcException` base class
  - [ ] 2.2.2 `AcdcNetworkException`
  - [ ] 2.2.3 `AcdcAuthException`
  - [ ] 2.2.4 `AcdcServerException`
  - [ ] 2.2.5 `AcdcClientException`
  - [ ] 2.2.6 `AcdcCacheException`
- [ ] 2.3 Define `LogLevel` enum in `lib/src/logging/log_level.dart`
- [ ] 2.4 Write unit tests for exception types

## 3. Error Handling Interceptor

- [ ] 3.1 Create `ErrorInterceptor` class in `lib/src/interceptors/error_interceptor.dart`
- [ ] 3.2 Implement HTTP status code to exception mapping
- [ ] 3.3 Add user-friendly error message generation
- [ ] 3.4 Handle network errors (timeouts, connection failures)
- [ ] 3.5 Write unit tests for error interceptor

## 4. Authentication Interceptor

- [ ] 4.1 Create `AuthInterceptor` class in `lib/src/interceptors/auth_interceptor.dart`
- [ ] 4.2 Implement Bearer token injection in request headers
- [ ] 4.3 Implement 401 detection and token refresh logic
- [ ] 4.4 Add request queue during token refresh (prevent duplicate refresh calls)
- [ ] 4.5 Write unit tests for auth interceptor
- [ ] 4.6 Write integration tests for token refresh flow

## 5. Logging Interceptor

- [ ] 5.1 Create `LoggingInterceptor` class in `lib/src/interceptors/logging_interceptor.dart`
- [ ] 5.2 Integrate `pretty_dio_logger` for debug mode
- [ ] 5.3 Implement minimal production logging with redaction
- [ ] 5.4 Add environment detection (`kDebugMode`)
- [ ] 5.5 Write unit tests for logging interceptor

## 6. Cache Configuration

- [ ] 6.1 Create `CacheConfig` class in `lib/src/cache/cache_config.dart`
- [ ] 6.2 Configure `dio_cache_interceptor` with sensible defaults
- [ ] 6.3 Implement cache policy options (TTL, max size)
- [ ] 6.4 Add cache invalidation helpers
- [ ] 6.5 Write unit tests for cache configuration

## 7. HTTP Client Builder

- [ ] 7.1 Create `AcdcClientBuilder` class in `lib/src/builder/acdc_client_builder.dart`
- [ ] 7.2 Implement fluent builder methods:
  - [ ] 7.2.1 `withBaseUrl(String url)`
  - [ ] 7.2.2 `withTimeout(Duration timeout)`
  - [ ] 7.2.3 `withTokenProvider(TokenProvider provider)`
  - [ ] 7.2.4 `withLogging(LogLevel level)`
  - [ ] 7.2.5 `withCache(CacheConfig config)`
  - [ ] 7.2.6 `disableCache()`
- [ ] 7.3 Implement `build()` method that returns configured `Dio` instance
- [ ] 7.4 Configure interceptor chain with correct order
- [ ] 7.5 Set default timeout values (connectTimeout, receiveTimeout, sendTimeout)
- [ ] 7.6 Write unit tests for builder
- [ ] 7.7 Write integration tests for complete client

## 8. Public API

- [ ] 8.1 Create `lib/dart_acdc.dart` with public exports
- [ ] 8.2 Export only necessary classes (builder, exceptions, interfaces)
- [ ] 8.3 Keep internal implementation in `lib/src/` private
- [ ] 8.4 Add dartdoc comments to all public APIs

## 9. Documentation

- [ ] 9.1 Write comprehensive README.md with:
  - [ ] 9.1.1 Installation instructions
  - [ ] 9.1.2 Quick start example
  - [ ] 9.1.3 Zero-config usage example
  - [ ] 9.1.4 Configuration examples
  - [ ] 9.1.5 OpenAPI integration example
- [ ] 9.2 Add dartdoc comments to all public classes and methods
- [ ] 9.3 Create `example/` directory with working example
- [ ] 9.4 Document supported Dart/Flutter versions

## 10. Testing

- [ ] 10.1 Ensure all unit tests pass
- [ ] 10.2 Ensure all integration tests pass
- [ ] 10.3 Run `dart analyze` with zero issues
- [ ] 10.4 Run `dart format` on all files
- [ ] 10.5 Achieve 80%+ code coverage
- [ ] 10.6 Test with openapi-generated client (manual integration test)

## 11. Example Project

- [ ] 11.1 Create `example/` directory
- [ ] 11.2 Create example Flutter app using dart_acdc
- [ ] 11.3 Include OpenAPI spec (e.g., JSONPlaceholder API)
- [ ] 11.4 Generate client using openapi-generator
- [ ] 11.5 Demonstrate zero-config usage
- [ ] 11.6 Demonstrate custom configuration
- [ ] 11.7 Add example README with instructions

## 12. Package Publishing Preparation

- [ ] 12.1 Verify `pubspec.yaml` metadata (description, homepage, repository)
- [ ] 12.2 Run `dart pub publish --dry-run`
- [ ] 12.3 Fix any pub.dev publishing warnings
- [ ] 12.4 Create initial git tag `v0.1.0`

## Dependencies

- Tasks 3-6 (Interceptors) can be done in parallel
- Task 7 (Builder) depends on tasks 2-6
- Task 8 (Public API) depends on task 7
- Task 9 (Documentation) can be done alongside implementation
- Task 10 (Testing) should be done continuously, finalized at end
- Task 11 (Example) depends on task 8
- Task 12 (Publishing prep) depends on all previous tasks

## Validation

After completing all tasks:

1. `dart analyze` returns zero issues
2. `dart test` passes all tests with 80%+ coverage
3. `dart format` shows no changes needed
4. Example app runs successfully on iOS and Android simulators
5. OpenAPI integration example works end-to-end
6. `dart pub publish --dry-run` succeeds with no warnings
