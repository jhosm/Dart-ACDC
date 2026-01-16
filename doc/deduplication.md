# Request Deduplication

Request deduplication is an optimization that prevents identical API calls from executing simultaneously.

## How It Works

If a second request is initiated while an identical first request is still pending, the library:
1.  Detects the duplicate.
2.  Suppresses the network call for the second request.
3.  Returns a `Future` that completes with the result of the *first* request.
4.  If the first request fails, both requests fail with the same error.

## Identity Criteria

Two requests are considered identical if they have the same:
-   HTTP Method (GET, POST, etc.)
-   URL (including query parameters)
-   Headers
-   Request Body
-   Response Type

## Usage

Deduplication is **enabled by default** in `AcdcClientBuilder`.

### Disabling Deduplication

To disable it globally:
```dart
final dio = AcdcClientBuilder()
    .withDeduplication(enabled: false)
    .build();
```

To disable it for a specific request (e.g., if the server response changes rapidly):
```dart
await dio.get('/random-data', options: Options(
  // TBD: Currently deduplication is global. 
  // Custom interceptors can be used to modify request identity.
));
```
*Note: The current implementation primarily supports global configuration.*
