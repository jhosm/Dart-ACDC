import 'package:dart_acdc/src/cache/jwt_utils.dart';

/// Result of a user ID extraction attempt.
class UserIdResult {
  /// Creates a [UserIdResult].
  const UserIdResult({
    required this.hasAuth,
    this.userId,
    this.token,
  });

  /// Whether the request has authentication headers.
  final bool hasAuth;

  /// The extracted user ID, if available.
  final String? userId;

  /// The extracted raw token, if available.
  final String? token;
}

/// Service responsible for extracting user IDs from authentication tokens.
///
/// This service encapsulates the logic for:
/// - Parsing Authorization headers
/// - Extracting tokens (Bearer or direct)
/// - Decoding user IDs from tokens (JWT or custom provider)
class UserIdExtractor {
  /// Creates a [UserIdExtractor].
  const UserIdExtractor({
    this.userIdProvider,
  });

  /// Custom provider to extract user ID from non-JWT tokens.
  final Future<String?> Function(String accessToken)? userIdProvider;

  /// Extracts user ID information from an Authorization header.
  ///
  /// Returns a [UserIdResult] containing:
  /// - [UserIdResult.hasAuth]: true if header is present and not empty
  /// - [UserIdResult.token]: The extracted token (stripped of "Bearer " prefix)
  /// - [UserIdResult.userId]: The extracted user ID if successful
  Future<UserIdResult> extract(String? authHeader) async {
    if (authHeader == null || authHeader.isEmpty) {
      return const UserIdResult(hasAuth: false);
    }

    final token = _extractToken(authHeader);
    if (token == null || token.isEmpty) {
      // Has auth header but no valid token
      return const UserIdResult(hasAuth: true);
    }

    // Try custom user ID provider first
    if (userIdProvider != null) {
      try {
        final userId = await userIdProvider!(token);
        if (userId != null && userId.isNotEmpty) {
          return UserIdResult(
            hasAuth: true,
            token: token,
            userId: userId,
          );
        }
      } on Exception catch (_) {
        // Custom provider failed - fall through to JWT extraction
      }
    }

    // Extract user ID from JWT
    final userId = JwtUtils.extractUserId(token);
    return UserIdResult(
      hasAuth: true,
      token: token,
      userId: userId,
    );
  }

  /// Extracts the token from Authorization header.
  ///
  /// Handles common formats:
  /// - "Bearer {token}"
  /// - "{token}"
  String? _extractToken(String authHeader) {
    final trimmed = authHeader.trim();

    // Handle "Bearer token" format
    if (trimmed.toLowerCase().startsWith('bearer ')) {
      final token = trimmed.substring(7).trim();
      return token.isNotEmpty ? token : null;
    }

    // Handle direct token format
    return trimmed.isNotEmpty ? trimmed : null;
  }
}
