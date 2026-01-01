# Authentication Specification

## Quick Start

For most mobile apps, authentication setup requires only three steps:

**Step 1**: Implement TokenProvider for secure storage
**Step 2**: Perform OAuth login using external library (e.g., flutter_appauth)
**Step 3**: Configure ACDC with token provider and refresh endpoint

```dart
// Step 1: Create token provider (use secure storage)
final tokenProvider = MySecureTokenProvider(); // Your implementation

// Step 2: OAuth login (handled by external library)
final authResult = await FlutterAppAuth().authorizeAndExchangeCode(...);
await tokenProvider.setTokens(
  accessToken: authResult.accessToken!,
  refreshToken: authResult.refreshToken,
  accessExpiry: authResult.accessTokenExpirationDateTime,
);

// Step 3: Configure ACDC - everything else is automatic
final dio = AcdcClientBuilder()
  .withTokenProvider(tokenProvider)
  .withTokenRefreshEndpoint(
    url: 'https://auth.example.com/oauth/token',
    clientId: 'my-mobile-app',
  )
  .build();

// Use with OpenAPI-generated client
final apiClient = MyApiClient(dio: dio);
final data = await apiClient.getData(); // Tokens injected + refreshed automatically
```

All token management is now automatic: proactive refresh before expiry, reactive refresh on 401, concurrent request queuing, and secure logout.

## ADDED Requirements

### Requirement: Token Provider Interface

The library SHALL define a `TokenProvider` interface for managing authentication tokens with secure storage and expiry tracking.

#### Scenario: Token provider interface contract

- **WHEN** a developer implements `TokenProvider`
- **THEN** they MUST provide methods:
  - `Future<String?> getAccessToken()` - Returns stored access token (may be expired)
  - `Future<String?> getRefreshToken()` - Returns stored refresh token
  - `Future<DateTime?> getAccessTokenExpiry()` - Returns access token expiry time in UTC (not local time)
  - `Future<DateTime?> getRefreshTokenExpiry()` - Returns refresh token expiry time in UTC (not local time)
  - `Future<void> setTokens({required String accessToken, String? refreshToken, DateTime? accessExpiry, DateTime? refreshExpiry})` - Stores tokens with expiry
  - `Future<void> clearTokens()` - Removes all stored tokens

#### Scenario: Secure token storage requirements

- **WHEN** a developer implements `TokenProvider`
- **THEN** tokens MUST be stored using platform-specific secure storage:
  - iOS: Keychain Services
  - Android: EncryptedSharedPreferences or Keystore
- **AND** tokens MUST NOT be stored in plain text (SharedPreferences, UserDefaults, etc.)
- **AND** implementations SHOULD clear tokens from memory after use (avoid keeping references)
- **AND** the library MUST provide example implementations for both platforms in documentation

#### Scenario: Token provider is not responsible for expiry validation

- **WHEN** `getAccessToken()` or `getRefreshToken()` is called
- **THEN** the provider returns the stored token regardless of expiry status
- **AND** the provider does NOT validate token expiry
- **AND** expiry validation is the library's responsibility (via interceptors)

#### Scenario: TokenProvider getAccessToken() throws exception

- **WHEN** `getAccessToken()` throws an exception during token retrieval
- **THEN** the exception is caught by the auth interceptor
- **AND** the request proceeds without authentication (no Authorization header)
- **AND** an error is logged indicating the token retrieval failure
- **AND** if the endpoint requires authentication, it will return 401 (handled normally)
- **AND** the exception does NOT crash the application

#### Scenario: TokenProvider setTokens() throws exception during refresh

- **WHEN** token refresh succeeds
- **AND** `setTokens()` throws an exception while storing the new tokens
- **THEN** the exception is caught by the auth interceptor
- **AND** an `AcdcAuthException` is thrown with message "Failed to store refreshed tokens"
- **AND** tokens are NOT cleared (old tokens remain in storage)
- **AND** the original request fails
- **AND** the error is logged with the storage exception details
- **AND** subsequent requests will retry the refresh (using old tokens)

#### Scenario: TokenProvider clearTokens() throws exception during logout

- **WHEN** `dio.auth.logout()` is called
- **AND** token revocation succeeds
- **AND** `clearTokens()` throws an exception
- **THEN** the exception is caught
- **AND** a warning is logged but logout is considered successful
- **AND** the library makes best-effort attempt to clear tokens despite storage failure
- **AND** the application treats the user as logged out
- **AND** subsequent requests will attempt to retrieve tokens (likely returning null)

#### Scenario: TokenProvider getRefreshToken() throws exception

- **WHEN** a 401 response triggers token refresh
- **AND** `getRefreshToken()` throws an exception
- **THEN** the exception is caught by the auth interceptor
- **AND** no refresh attempt is made (cannot retrieve refresh token)
- **AND** `AcdcAuthException` is thrown with message "Failed to retrieve refresh token"
- **AND** tokens are NOT cleared (may be temporary storage issue)
- **AND** the error is logged with the exception details

### Requirement: Bearer Token Injection

The library SHALL automatically inject Bearer tokens into request headers when a TokenProvider is configured and tokens are valid.

#### Scenario: Automatic token injection with expiry check

- **WHEN** a request is about to be made
- **AND** a TokenProvider is configured
- **THEN** the auth interceptor retrieves `getAccessToken()` and `getAccessTokenExpiry()`
- **AND** if the token is valid (not expired or expiring within threshold), adds `Authorization: Bearer <token>` header
- **AND** the request proceeds with the token

#### Scenario: Request without token

- **WHEN** a request is made and `getAccessToken()` returns null
- **THEN** no Authorization header is added
- **AND** the request proceeds without authentication

#### Scenario: Existing Authorization header is preserved

- **WHEN** a developer manually sets an Authorization header on a specific request
- **THEN** the auth interceptor MUST NOT override it
- **AND** the manual header takes precedence
- **AND** no automatic token injection occurs for that request

### Requirement: Proactive Token Refresh

The library SHALL proactively refresh access tokens before they expire to prevent user-facing errors.

#### Scenario: Token expiry check triggers proactive refresh

- **WHEN** a request is about to be made
- **AND** a TokenProvider is configured
- **AND** `getAccessTokenExpiry()` returns a valid expiry time
- **AND** the token expires within the refresh threshold (configurable, default: 60 seconds)
- **THEN** the auth interceptor triggers token refresh before proceeding
- **AND** queues the current request until refresh completes
- **AND** proceeds with the new token
- **AND** if proactive refresh fails due to network/server error, the request fails with the refresh error
- **AND** if proactive refresh fails due to auth error (invalid_grant), tokens are cleared and request fails with AcdcAuthException

#### Scenario: Configurable refresh threshold

- **WHEN** a developer configures the refresh threshold
- **THEN** they can specify a custom duration via `withTokenRefreshThreshold(Duration threshold)`
- **AND** the library uses this threshold for proactive refresh decisions
- **AND** the threshold MUST be a positive duration (minimum: 1 second)
- **AND** if threshold is zero or negative, the library throws ArgumentError

```dart
final dio = AcdcClientBuilder()
  .withTokenProvider(myTokenProvider)
  .withTokenRefreshThreshold(Duration(seconds: 30)) // Custom threshold
  .build();
```

#### Scenario: Proactive refresh falls back to reactive

- **WHEN** token expiry information is not available (`getAccessTokenExpiry()` returns null)
- **THEN** proactive refresh is disabled
- **AND** the library relies solely on reactive refresh (401 response handling)

### Requirement: Reactive Token Auto-Refresh on 401

The library SHALL automatically attempt to refresh expired tokens when a 401 Unauthorized response is received.

#### Scenario: 401 triggers token refresh flow

- **WHEN** a request returns a 401 Unauthorized response
- **AND** a TokenProvider is configured
- **AND** a refresh token is available via `getRefreshToken()`
- **THEN** the auth interceptor initiates token refresh using the configured refresh endpoint
- **AND** if refresh succeeds, stores new tokens via `setTokens()`
- **AND** retries the original request with the new access token
- **AND** returns the retry response to the caller (transparent refresh)
- **AND** if refresh fails, clears tokens via `clearTokens()` and throws `AcdcAuthException`

#### Scenario: 401 without refresh token

- **WHEN** a 401 response is received
- **AND** `getRefreshToken()` returns null
- **THEN** no refresh attempt is made
- **AND** `AcdcAuthException` is thrown immediately
- **AND** the application should initiate re-authentication (login flow)

#### Scenario: Expired refresh token detection

- **WHEN** token refresh is about to be triggered
- **AND** `getRefreshTokenExpiry()` returns a time in the past
- **THEN** no refresh attempt is made
- **AND** tokens are cleared via `clearTokens()`
- **AND** `AcdcAuthException` is thrown with message "Refresh token expired. Please log in again."

#### Scenario: Single retry attempt per request

- **WHEN** a refreshed token is used to retry a failed request
- **AND** the retry also returns 401
- **THEN** no additional refresh is attempted
- **AND** `AcdcAuthException` is thrown with message "Authentication failed after token refresh"
- **AND** tokens are cleared (likely server-side session invalidation)

### Requirement: Concurrent Request Queuing During Refresh

The library SHALL queue concurrent requests while a token refresh is in progress to prevent duplicate refresh attempts.

#### Scenario: Single refresh for multiple requests

- **WHEN** multiple requests detect token expiry simultaneously (proactive or reactive)
- **THEN** only the first request triggers token refresh
- **AND** subsequent requests are queued and wait for refresh completion
- **AND** once refresh succeeds, all queued requests proceed with the new token
- **AND** if refresh fails, all queued requests fail with the same `AcdcAuthException`

#### Scenario: Refresh queue timeout

- **WHEN** a token refresh takes longer than the queue timeout (configurable, default: 10 seconds)
- **THEN** all waiting requests fail with `AcdcAuthException`
- **AND** the error message indicates "Token refresh timeout"
- **AND** tokens are cleared via `clearTokens()`

#### Scenario: Logout called during active token refresh

- **WHEN** a token refresh is in progress
- **AND** `dio.auth.logout()` is called
- **THEN** the logout operation takes priority
- **AND** the in-progress refresh request is cancelled
- **AND** all queued requests waiting for refresh fail with `AcdcAuthException` indicating logout
- **AND** tokens are revoked and cleared via the normal logout flow
- **AND** the logout completes successfully
- **AND** subsequent requests will not have authentication

### Requirement: App Lifecycle Handling

The library SHALL handle app lifecycle events gracefully during token refresh to prevent data loss and inconsistent state.

#### Scenario: App backgrounded during token refresh

- **WHEN** the app is sent to background while a token refresh is in progress
- **THEN** the refresh request continues in the background (if OS allows)
- **AND** queued requests remain queued
- **AND** when the app returns to foreground, queued requests proceed with refreshed tokens
- **AND** if background execution is not allowed, refresh is cancelled gracefully

#### Scenario: App killed during token refresh

- **WHEN** the app process is killed while a token refresh is in progress
- **THEN** on next app launch, the refresh state is not persisted
- **AND** tokens remain in their pre-refresh state (old tokens not cleared)
- **AND** the next API request triggers a new refresh attempt
- **AND** no duplicate refresh occurs (old refresh was cancelled)

#### Scenario: Network changes during refresh

- **WHEN** the network connection changes (WiFi to cellular, or vice versa) during token refresh
- **THEN** the refresh request adapts to the new connection
- **AND** if the network becomes unavailable, the refresh fails with `AcdcNetworkException`
- **AND** queued requests can retry when network returns

### Requirement: Token Refresh Endpoint Configuration

The library SHALL allow developers to configure the token refresh endpoint for OAuth 2.1 compliant servers.

#### Scenario: Simple refresh endpoint configuration (public clients only)

- **WHEN** a developer configures token refresh endpoint for a mobile app
- **THEN** they provide only the endpoint URL and client ID (NO client secret)

```dart
final dio = AcdcClientBuilder()
  .withTokenProvider(myTokenProvider)
  .withTokenRefreshEndpoint(
    url: 'https://auth.example.com/oauth/token',
    clientId: 'my-mobile-app-id',
  )
  .build();
```

#### Scenario: Refresh request construction

- **WHEN** token refresh is triggered
- **THEN** a POST request is made to the refresh endpoint
- **AND** uses application/x-www-form-urlencoded content type
- **AND** includes these parameters:
  - `grant_type=refresh_token` (required)
  - `refresh_token=<current-refresh-token>` (required)
  - `client_id=<configured-client-id>` (required)
- **AND** does NOT include `client_secret` parameter (mobile apps are public clients per OAuth 2.1)

#### Scenario: Refresh response parsing with clock skew handling

- **WHEN** the refresh endpoint returns a successful response (200 OK)
- **THEN** the library parses the JSON response
- **AND** extracts `access_token` (required)
- **AND** extracts `refresh_token` (optional, for token rotation)
- **AND** extracts `expires_in` (optional, seconds until expiry)
- **AND** if `expires_in` is present, calculates expiry as:
  - Uses server time from `Date` response header if available (prevents clock skew)
  - Falls back to local time (`DateTime.now().add(Duration(seconds: expiresIn))`) if `Date` header absent
- **AND** stores tokens with calculated expiry via `setTokens()`

#### Scenario: Custom refresh logic

- **WHEN** a developer needs non-standard refresh logic (custom parameters, non-OAuth endpoint)
- **THEN** they provide a custom refresh function via `withCustomTokenRefresh()`

```dart
final dio = AcdcClientBuilder()
  .withTokenProvider(myTokenProvider)
  .withCustomTokenRefresh((refreshToken) async {
    final response = await customAuthClient.refreshToken(refreshToken);
    return TokenRefreshResult(
      accessToken: response.accessToken,
      refreshToken: response.newRefreshToken,
      accessExpiry: DateTime.now().add(Duration(seconds: response.expiresIn)),
    );
  })
  .build();
```

#### Scenario: TokenRefreshResult structure

- **WHEN** a custom refresh function is used
- **THEN** it MUST return a `TokenRefreshResult` object with:
  - `String accessToken` - New access token (required)
  - `String? refreshToken` - New refresh token (optional, for rotation)
  - `DateTime? accessExpiry` - Access token expiry in UTC (optional)
  - `DateTime? refreshExpiry` - Refresh token expiry in UTC (optional)

### Requirement: Token Refresh Error Handling

The library SHALL provide detailed error handling for token refresh failures with actionable error messages.

#### Scenario: OAuth error response handling

- **WHEN** the refresh endpoint returns an OAuth error response
- **THEN** the library parses the `error` field from JSON
- **AND** maps OAuth error codes to `AcdcAuthException` with specific messages:
  - `invalid_grant` → "Refresh token expired or invalid. Please log in again."
  - `invalid_client` → "Client authentication failed. Check client configuration."
  - `unauthorized_client` → "Client not authorized for token refresh."
  - `unsupported_grant_type` → "Server does not support refresh token grant."
- **AND** includes the `error_description` field if present
- **AND** clears tokens via `clearTokens()` (auth issue, requires re-login)

#### Scenario: Network error during refresh

- **WHEN** the refresh request fails due to network error (timeout, no connection)
- **THEN** an `AcdcNetworkException` is thrown
- **AND** tokens are NOT cleared (temporary network issue, not auth failure)
- **AND** the error message is "Token refresh failed due to network error"
- **AND** the application can retry or queue the request for later

#### Scenario: Server error during refresh

- **WHEN** the refresh request returns a 5xx server error
- **THEN** an `AcdcServerException` is thrown
- **AND** tokens are NOT cleared (server issue, not auth failure)
- **AND** the error message is "Token refresh failed due to server error"
- **AND** the application can retry with exponential backoff

#### Scenario: Exponential backoff for repeated server errors

- **WHEN** token refresh fails with a 5xx error
- **AND** subsequent requests also require refresh
- **THEN** the library applies exponential backoff (1s, 2s, 4s, max 30s)
- **AND** queued requests wait during backoff period
- **AND** backoff resets after successful refresh

### Requirement: Token Refresh Isolation

The library SHALL execute token refresh requests independently from the configured Dio interceptor chain to prevent recursion and sensitive data leakage.

#### Scenario: Separate HTTP client for refresh requests

- **WHEN** a token refresh request is made
- **THEN** it uses a separate, minimal Dio instance (not the main configured instance)
- **AND** the refresh request bypasses these interceptors:
  - Auth interceptor (prevents infinite loop)
  - Cache interceptor (tokens must not be cached)
  - Custom user interceptors (prevents side effects)
- **AND** the refresh request includes:
  - Error interceptor (for proper error categorization)
  - Minimal logging (redacted, see next scenario)

#### Scenario: Refresh request logging redaction

- **WHEN** a refresh request or response is logged
- **THEN** sensitive fields are redacted:
  - Request: `refresh_token` parameter → `[REDACTED]`
  - Response: `access_token` field → `[REDACTED]`
  - Response: `refresh_token` field → `[REDACTED]`
- **AND** non-sensitive fields are logged normally (URL, status code, duration)

### Requirement: Token Revocation and Logout

The library SHALL support token revocation during logout to invalidate tokens server-side.

#### Scenario: Auth manager provides logout method

- **WHEN** the library is configured with a revocation endpoint
- **THEN** the built Dio instance includes an auth manager accessible via extension

```dart
final dio = AcdcClientBuilder()
  .withTokenProvider(myTokenProvider)
  .withTokenRefreshEndpoint(...)
  .withTokenRevocationEndpoint('https://auth.example.com/oauth/revoke')
  .build();

// Later, during logout
await dio.auth.logout(); // Revokes tokens and clears local storage
```

#### Scenario: Logout revokes both tokens

- **WHEN** `dio.auth.logout()` is called
- **THEN** the library attempts to revoke both tokens:
  - First revokes refresh token (via revocation endpoint)
  - Then revokes access token (via revocation endpoint)
- **AND** clears tokens locally via `clearTokens()` regardless of revocation success
- **AND** completes successfully even if revocation requests fail (best-effort)

#### Scenario: Revocation request construction

- **WHEN** token revocation is triggered
- **THEN** a POST request is made to the revocation endpoint for each token
- **AND** uses application/x-www-form-urlencoded content type
- **AND** includes these parameters:
  - `token=<token-value>` (access or refresh token)
  - `token_type_hint=<access_token|refresh_token>`
  - `client_id=<configured-client-id>`

#### Scenario: Revocation failure handling

- **WHEN** a revocation request fails (network error, 5xx, or 404)
- **THEN** a warning is logged (not an error)
- **AND** tokens are still cleared locally
- **AND** logout completes successfully
- **AND** the application considers the user logged out

#### Scenario: Logout without revocation endpoint

- **WHEN** no revocation endpoint is configured
- **AND** `dio.auth.logout()` is called
- **THEN** tokens are cleared locally via `clearTokens()`
- **AND** no network requests are made
- **AND** logout completes successfully

### Requirement: Token Rotation Support

The library SHALL support refresh token rotation for enhanced security.

#### Scenario: Refresh token rotation

- **WHEN** the refresh endpoint returns a new refresh token in the response
- **THEN** both the access token and refresh token are updated via `setTokens()`
- **AND** the old refresh token is invalidated by the server
- **AND** future refresh requests use the new refresh token

#### Scenario: No token rotation

- **WHEN** the refresh response does not include a new refresh token
- **THEN** only the access token is updated
- **AND** the existing refresh token is retained
- **AND** `setTokens()` is called with the new access token and existing refresh token

### Requirement: Optional Authentication

The library SHALL support requests without authentication when no TokenProvider is configured.

#### Scenario: Public API requests

- **WHEN** no TokenProvider is configured
- **THEN** requests proceed without Authorization headers
- **AND** no token refresh logic is active
- **AND** 401 responses are treated as regular client errors (`AcdcClientException`)

#### Scenario: Mixed public and authenticated endpoints

- **WHEN** a TokenProvider is configured
- **AND** `getAccessToken()` returns null for some requests
- **THEN** requests without tokens proceed without Authorization headers (public endpoints)
- **AND** requests with valid tokens include Authorization headers (authenticated endpoints)

## REMOVED Requirements

None - this is a new capability.

## MODIFIED Requirements

None - this is a new capability.
