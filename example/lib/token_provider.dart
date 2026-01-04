import 'dart:async';
import 'package:dart_acdc/dart_acdc.dart';

/// A mock token provider that stores tokens in memory.
///
/// In a real app, you would use `flutter_secure_storage` or similar
/// to persist tokens securely.
class MockTokenProvider implements TokenProvider {
  String? _accessToken;
  String? _refreshToken;
  DateTime? _accessExpiry;
  DateTime? _refreshExpiry;

  bool get isLoggedIn => _accessToken != null;

  /// Simulate a login by generating fake tokens
  Future<void> login() async {
    // In a real app, you would exchange credentials for tokens here.
    _accessToken = 'mock_access_token_${DateTime.now().millisecondsSinceEpoch}';
    _refreshToken =
        'mock_refresh_token_${DateTime.now().millisecondsSinceEpoch}';

    // Set expiry to 1 hour from now for access token
    _accessExpiry = DateTime.now().add(const Duration(hours: 1));

    // Set expiry to 30 days from now for refresh token
    _refreshExpiry = DateTime.now().add(const Duration(days: 30));
  }

  @override
  Future<String?> getAccessToken() async => _accessToken;

  @override
  Future<String?> getRefreshToken() async => _refreshToken;

  @override
  Future<DateTime?> getAccessTokenExpiry() async => _accessExpiry;

  @override
  Future<DateTime?> getRefreshTokenExpiry() async => _refreshExpiry;

  @override
  Future<void> setTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? accessExpiry,
    DateTime? refreshExpiry,
  }) async {
    _accessToken = accessToken;
    if (refreshToken != null) _refreshToken = refreshToken;
    _accessExpiry = accessExpiry;
    _refreshExpiry = refreshExpiry;
  }

  @override
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _accessExpiry = null;
    _refreshExpiry = null;
  }
}
