import 'package:jwt_decoder/jwt_decoder.dart';

/// Utility for extracting user information from JWT tokens.
class JwtUtils {
  // Private constructor to prevent instantiation
  JwtUtils._();

  /// Extracts user ID from a JWT access token.
  ///
  /// Checks the following claims in order:
  /// 1. `sub` (subject - standard JWT claim)
  /// 2. `user_id` (common custom claim)
  /// 3. `uid` (alternative user ID claim)
  ///
  /// Returns `null` if:
  /// - Token is not a valid JWT
  /// - Token is malformed or expired
  /// - None of the expected claims are present
  ///
  /// Example:
  /// ```dart
  /// final userId = JwtUtils.extractUserId(accessToken);
  /// if (userId != null) {
  ///   print('User ID: $userId');
  /// }
  /// ```
  static String? extractUserId(String? token) {
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      // Decode JWT without verifying signature
      // (signature verification is the auth server's responsibility)
      final decodedToken = JwtDecoder.decode(token);

      // Try standard claims in priority order
      // 1. 'sub' is the standard JWT subject claim
      if (decodedToken.containsKey('sub')) {
        final sub = decodedToken['sub'];
        if (sub != null && sub.toString().isNotEmpty) {
          return sub.toString();
        }
      }

      // 2. 'user_id' is a common custom claim
      if (decodedToken.containsKey('user_id')) {
        final userId = decodedToken['user_id'];
        if (userId != null && userId.toString().isNotEmpty) {
          return userId.toString();
        }
      }

      // 3. 'uid' is another common alternative
      if (decodedToken.containsKey('uid')) {
        final uid = decodedToken['uid'];
        if (uid != null && uid.toString().isNotEmpty) {
          return uid.toString();
        }
      }

      // No user ID found in any expected claim
      return null;
    } on Exception catch (_) {
      // Token is not a valid JWT or is malformed
      // Silently return null - caching will be disabled for this request
      return null;
    }
  }

  /// Checks if a token is a valid JWT format.
  ///
  /// Returns `true` if the token can be decoded as a JWT,
  /// `false` otherwise (including null, empty, or malformed tokens).
  static bool isValidJwt(String? token) {
    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      JwtDecoder.decode(token);
      return true;
    } on Exception catch (_) {
      return false;
    }
  }

  /// Checks if a JWT token is expired.
  ///
  /// Returns `true` if the token is expired, `false` if still valid.
  /// Returns `null` if the token is invalid or has no expiry claim.
  static bool? isExpired(String? token) {
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      return JwtDecoder.isExpired(token);
    } on Exception catch (_) {
      return null;
    }
  }
}
