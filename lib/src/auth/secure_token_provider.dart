import 'package:dart_acdc/src/auth/token_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A secure implementation of [TokenProvider] using [FlutterSecureStorage].
///
/// Stores tokens in the device's secure storage (Keychain on iOS, Keystore on Android).
/// This is the default implementation used by [AcdcClientBuilder].
class SecureTokenProvider implements TokenProvider {
  /// Creates a new [SecureTokenProvider].
  ///
  /// [storage] can be provided for testing or custom configuration.
  /// If not provided, a default [FlutterSecureStorage] instance is used with
  /// secure defaults:
  /// - Android: EncryptedSharedPreferences enabled
  /// - iOS: Keychain accessible after first unlock
  const SecureTokenProvider({
    FlutterSecureStorage? storage,
  }) : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  static const String _keyAccessToken = 'acdc_access_token';
  static const String _keyRefreshToken = 'acdc_refresh_token';
  static const String _keyAccessExpiry = 'acdc_access_expiry';
  static const String _keyRefreshExpiry = 'acdc_refresh_expiry';

  @override
  Future<String?> getAccessToken() => _storage.read(key: _keyAccessToken);

  @override
  Future<String?> getRefreshToken() => _storage.read(key: _keyRefreshToken);

  @override
  Future<DateTime?> getAccessTokenExpiry() async {
    final expiryProfile = await _storage.read(key: _keyAccessExpiry);
    return expiryProfile != null ? DateTime.tryParse(expiryProfile) : null;
  }

  @override
  Future<DateTime?> getRefreshTokenExpiry() async {
    final expiry = await _storage.read(key: _keyRefreshExpiry);
    return expiry != null ? DateTime.tryParse(expiry) : null;
  }

  @override
  Future<void> setTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? accessExpiry,
    DateTime? refreshExpiry,
  }) async {
    await Future.wait([
      _storage.write(key: _keyAccessToken, value: accessToken),
      if (refreshToken != null)
        _storage.write(key: _keyRefreshToken, value: refreshToken),
      if (accessExpiry != null)
        _storage.write(
          key: _keyAccessExpiry,
          value: accessExpiry.toIso8601String(),
        ),
      if (refreshExpiry != null)
        _storage.write(
          key: _keyRefreshExpiry,
          value: refreshExpiry.toIso8601String(),
        ),
    ]);
  }

  @override
  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _keyAccessToken),
      _storage.delete(key: _keyRefreshToken),
      _storage.delete(key: _keyAccessExpiry),
      _storage.delete(key: _keyRefreshExpiry),
    ]);
  }
}
