# Platform Testing Procedures

This document outlines the manual testing procedures for verifying `dart_acdc` functionality on Android and iOS platforms. While unit and integration tests cover logic, platform-specific features like secure storage and network connectivity require verification on real devices or emulators.

## Prerequisites

*   Flutter SDK installed and configured.
*   Android Studio (for Android Emulator) and/or Xcode (for iOS Simulator).
*   A physical Android device or iPhone (optional but recommended).

## General Testing Checklist

Perform these checks on every major release or when modifying platform-specific code (e.g., `flutter_secure_storage` updates, connectivity changes).

### 1. Authentication Flow
*   [ ] **Login**: Verify successful login with valid credentials using the example app.
*   [ ] **Token Storage**: Kill the app and restart. Verify the session is restored (tokens persisted).
*   [ ] **Logout**: Verify successful logout clears local tokens. Restart app to confirm user is logged out.

### 2. Token Refresh
*   [ ] **Proactive Refresh**: Use the example app's "Force Token Expiry" debug option (if available) or wait for token expiry. Verify requests continue to succeed without user intervention.
*   [ ] **Reactive Refresh (401)**: Trigger a 401 response (e.g., via debug endpoint or revoking token console-side). Verify the client automatically refreshes the token and retries the request.

### 3. Network Connectivity
*   [ ] **Offline Mode**:
    1.  Enable Airplane Mode on the device/emulator.
    2.  Attempt an API request.
    3.  Verify `AcdcNetworkException` is thrown (or cache data returned if caching enabled).
    4.  Disable Airplane Mode.
    5.  Verify requests succeed again.

## Android-Specific Testing

### Setup
Run the example app:
```bash
cd example
flutter run -d android
```

### Security Verification
*   **Secure Storage**: Verify tokens are stored in the Android Keystore.
    *   *Verification*: On a rooted emulator or using `adb run-as`, check that shared preferences do NOT contain plain-text tokens.

## iOS-Specific Testing

### Setup
Run the example app:
```bash
cd example
flutter run -d ios
```

### Security Verification
*   **Secure Storage**: Verify tokens are stored in the iOS Keychain.
    *   *Verification*: Uninstalling and reinstalling the app should (by default) retain the keychain data unless configured otherwise. Verify behavior matches `flutter_secure_storage` configuration.

## Troubleshooting

*   **"PlatformException(Exception encountered, read, ...)"**: Often related to secure storage configuration. Check `android/app/build.gradle` (minSdkVersion >= 18) and iOS capabilities (Keychain Sharing).
*   **Network Errors on Emulator**: Ensure the emulator has internet access. Android emulators use `10.0.2.2` for localhost; iOS uses `localhost`.
