# Dart ACDC Example (Google Tasks & Public API)

This project demonstrates how to use `dart_acdc` to build a production-ready HTTP client for the **Google Tasks API** and public APIs.

It showcases the **"Zero-Config"** philosophy: simply build a `Dio` instance with `dart_acdc` and get free logging, error handling, caching, and token management.

## Features Demonstrated

*   **Authentication**:
    *   Authenticates with Google using **Implicit Flow** (via `flutter_web_auth_2`).
    *   Securely stores tokens using `SecureTokenProvider`.
    *   Automatically injects Bearer tokens into requests.
*   **Smart Caching**:
    *   **Authenticated Cache**: Caches your private task lists (user-isolated).
    *   **Public API Cache**: Demonstrates standard `max-age` caching using `httpbin.org/cache`.
    *   **Force Refresh**: Bypass cache on demand.
*   **Observability**:
    *   Real-time request/response logging in the UI with redaction of sensitive data.

## Setup Requirements

To run the **Google Tasks** demo, you must have a Google Cloud Project with the **Google Tasks API** enabled.

1.  Create a Client ID for **Web Application** in Google Cloud Console.
2.  Add `http://localhost:3000` (or your app's origin) to **Authorized-JavaScript Origins**.
3.  Add `http://localhost:3000/callback.html` to **Authorized Redirect URIs**.
4.  Copy your **Client ID**.

**Note:** The Public API feature (HttpBin) does not require authentication setup.

## How to Run

### Web

1.  Ensure you have `http://localhost:3000` configured in Google Cloud (for Google Auth).
2.  Run with the fixed port:

```bash
cd example
flutter run -d chrome --web-port 3000
```
3.  Enter your **Client ID** in the app's UI to login.

### Public API Test

You can test the public API caching feature without logging in. Just click "Fetch Public (Max-Age: 10s)" in the UI.

### Mobile (iOS/Android)
*(Note: Mobile setup requires deep linking configuration. See `AndroidManifest.xml` and `Info.plist`).*

1.  Configure Android/iOS deep links for `dartacdc://callback`.
2.  Run `flutter run`.
