# Change: Add Core Library Architecture

## Why

This is the initial architecture for Dart-ACDC, establishing the foundational components that enable zero-config REST API consumption with best practices. Without this foundation, developers cannot use the library for OpenAPI-generated clients or benefit from the opinionated HTTP client configuration.

**Problem:**
- No Dart/Flutter package structure exists
- Developers need to manually configure Dio with interceptors, error handling, caching, and authentication
- No standardized way to provide a pre-configured Dio instance to openapi-generated clients

**Opportunity:**
- Create a batteries-included HTTP client that works out-of-the-box
- Establish clear architectural patterns for the MVP and future features
- Enable the developer workflow: OpenAPI YAML → Code Generation → ACDC Dio Instance

## What Changes

### New Capabilities

1. **HTTP Client Factory** - Builder/Factory pattern for creating pre-configured Dio instances
2. **Error Handling** - Custom exception types and error interceptor
3. **Authentication** - Token injection and auto-refresh interceptor
4. **Logging** - Environment-aware logging (dev/prod modes)
5. **Caching** - HTTP cache configuration with sensible defaults

### Package Structure

- `lib/` - Library source code
  - `lib/src/` - Internal implementation
  - `lib/dart_acdc.dart` - Public API export
- `test/` - Unit and integration tests
- `pubspec.yaml` - Package manifest with dependencies
- `analysis_options.yaml` - Dart analyzer configuration

### Dependencies (Initial)

- `dio` - Core HTTP client
- `dio_cache_interceptor` - Response caching
- `pretty_dio_logger` - Development logging

## Impact

### Affected Specs

- **NEW**: `http-client` - Core Dio factory and builder
- **NEW**: `error-handling` - Exception types and error interceptor
- **NEW**: `authentication` - Auth token management
- **NEW**: `logging` - Logging interceptor
- **NEW**: `caching` - Cache interceptor configuration

### Affected Code

- **NEW**: All initial library code (greenfield)
- **NEW**: Package configuration (`pubspec.yaml`, `analysis_options.yaml`)
- **NEW**: Test infrastructure

### Breaking Changes

None - this is the initial release.

### Migration Path

Not applicable - this is the first version.
