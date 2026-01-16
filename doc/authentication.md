# Authentication

Dart-ACDC provides a robust authentication system based on OAuth 2.1 principles. It handles token injection, automatic refreshing (reactive and proactive), and concurrent request queuing.

## Architecture

The authentication system consists of:

1.  **TokenProvider**: Persistent storage for access and refresh tokens.
2.  **AuthInterceptor**: Intercepts requests to inject tokens and handles 401 responses.
3.  **AcdcAuthManager**: Manages high-level operations like logout and manual refresh.

## Configuration

### Basic OAuth 2.1 Refresh

To enable automatic token refreshing using standard OAuth endpoints:

```dart
final dio = AcdcClientBuilder()
    .withBaseUrl('https://api.example.com')
    .withTokenProvider(SecureTokenProvider()) // Uses secure storage
    .withTokenRefreshEndpoint(
      url: 'https://auth.example.com/oauth/token',
      clientId: 'mobile-app',
    )
    .build();
```

The library will:
1.  Inject `Authorization: Bearer <token>` on all requests.
2.  If any request fails with `401 Unauthorized`, it pauses all pending requests.
3.  It attempts to refresh the token using the refresh endpoint.
4.  On success, it retries the original request and all queued requests.
5.  On failure, it throws `AcdcAuthException`.

### Custom Token Refresh

If your backend uses a non-standard refresh flow:

```dart
.withCustomTokenRefresh((refreshToken) async {
  // Call your custom API
  final response = await myCustomApi.refresh(refreshToken);
  
  return TokenRefreshResult(
    accessToken: response.newAccessToken,
    refreshToken: response.newRefreshToken, // Optional rotation
  );
})
```

### Proactive Refresh

ACDC tracks token expiry (if provided) and refreshes tokens *before* they expire to prevent 401s.

```dart
.withTokenRefreshThreshold(Duration(minutes: 5)) // Refresh 5 mins before expiry
```

## Token Storage

The `TokenProvider` interface abstracts storage. We recommend using `SecureTokenProvider` (included), which uses `flutter_secure_storage` implementation is assumed or you can provide your own.

### Implementing a Custom Provider

```dart
class MyTokenProvider implements TokenProvider {
  @override
  Future<String?> getAccessToken() async {
    // Return token from your storage
  }

  @override
  Future<void> setTokens({required String accessToken, ...}) async {
    // Save tokens and expiry dates
  }
  
  // ... implement other methods
}
```

## Manual Operations

Access the `AcdcAuthManager` via `dio.auth`:

### Logout

Performing a logout will:
1.  Cancel pending refreshes.
2.  Clear the user-specific cache.
3.  Call the revocation endpoint (if configured).
4.  Clear tokens from storage.

```dart
// Configure revocation
.withTokenRevocationEndpoint('https://auth.example.com/revoke')

// Usage
await dio.auth.logout();
```

### Force Refresh

```dart
await dio.auth.refreshNow();
```

## Initializing with Tokens

If the user logs in, initialize the client with their tokens:

```dart
final dio = AcdcClientBuilder()
    .withInitialTokens(
       accessToken: '...',
       refreshToken: '...',
    )
    .build();
```
