# Authentication Specification

## ADDED Requirements

### Requirement: Token Provider Interface

The library SHALL define a `TokenProvider` interface for managing authentication tokens independently of storage implementation.

#### Scenario: Token provider interface contract

- **WHEN** a developer implements `TokenProvider`
- **THEN** they MUST provide methods:
  - `Future<String?> getAccessToken()`
  - `Future<String?> getRefreshToken()`
  - `Future<void> setTokens(String accessToken, String? refreshToken)`
  - `Future<void> clearTokens()`

#### Scenario: Platform-specific token storage

- **WHEN** a developer needs to use secure storage (Keychain, Keystore)
- **THEN** they can implement `TokenProvider` with platform-specific storage
- **AND** pass it to `AcdcClientBuilder.withTokenProvider(provider)`

### Requirement: Bearer Token Injection

The library SHALL automatically inject Bearer tokens into request headers when a TokenProvider is configured.

#### Scenario: Automatic token injection

- **WHEN** a request is made with a configured TokenProvider
- **THEN** the auth interceptor calls `getAccessToken()`
- **AND** adds `Authorization: Bearer <token>` header to the request
- **AND** the request proceeds with the token

#### Scenario: Request without token

- **WHEN** a request is made and `getAccessToken()` returns null
- **THEN** no Authorization header is added
- **AND** the request proceeds without authentication

### Requirement: Token Auto-Refresh on 401

The library SHALL automatically attempt to refresh expired tokens when a 401 Unauthorized response is received.

#### Scenario: 401 triggers token refresh

- **WHEN** a request returns a 401 Unauthorized response
- **AND** a TokenProvider is configured
- **AND** a refresh token is available
- **THEN** the auth interceptor calls the refresh token endpoint
- **AND** updates tokens via `setTokens()`
- **AND** retries the original request with the new access token

#### Scenario: Successful token refresh and retry

- **WHEN** token refresh succeeds
- **THEN** the new access token is stored via `setTokens()`
- **AND** the original request is retried with the new token
- **AND** the retry response is returned to the caller

#### Scenario: Failed token refresh

- **WHEN** token refresh fails (refresh token expired or invalid)
- **THEN** `clearTokens()` is called
- **AND** an `AcdcAuthException` is thrown
- **AND** the original request is not retried

### Requirement: Concurrent Request Queuing During Refresh

The library SHALL queue concurrent requests while a token refresh is in progress to prevent duplicate refresh attempts.

#### Scenario: Multiple requests during token refresh

- **WHEN** multiple requests receive 401 responses simultaneously
- **THEN** only one token refresh request is made
- **AND** subsequent requests wait for the refresh to complete
- **AND** all waiting requests are retried with the new token

#### Scenario: Request queue timeout

- **WHEN** a token refresh takes longer than a reasonable timeout (e.g., 10 seconds)
- **THEN** waiting requests fail with `AcdcAuthException`
- **AND** the error message indicates token refresh timeout

### Requirement: Token Refresh Endpoint Configuration

The library SHALL allow developers to configure a custom token refresh function.

#### Scenario: Custom refresh logic

- **WHEN** a developer provides a refresh function via `withTokenRefresh()`
- **THEN** the auth interceptor uses the custom function
- **AND** the function receives the current refresh token
- **AND** the function returns new access and refresh tokens

```dart
final dio = AcdcClientBuilder()
  .withTokenProvider(myTokenProvider)
  .withTokenRefresh((refreshToken) async {
    final response = await authApi.refreshToken(refreshToken);
    return (
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
    );
  })
  .build();
```

### Requirement: Optional Authentication

The library SHALL support requests without authentication when no TokenProvider is configured.

#### Scenario: Public API requests

- **WHEN** no TokenProvider is configured
- **THEN** requests proceed without Authorization headers
- **AND** no token refresh logic is active
- **AND** 401 responses are treated as regular client errors
