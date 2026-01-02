import 'package:dart_acdc/src/cache/jwt_utils.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

/// Builds cache keys with user-based isolation for authenticated requests.
///
/// Caching behavior:
/// - **Unauthenticated requests**: Standard cache key `{method}:{url}` (shared)
/// - **Authenticated with user ID**: User-isolated key `{method}:{url}:{userId}`
/// - **Authenticated without user ID**: Returns `null` (no caching for security)
///
/// User ID is extracted from JWT or custom provider.
class UserCacheKeyBuilder {
  /// Creates a user-aware cache key builder.
  ///
  /// [userIdProvider] is an optional custom function to extract user ID
  /// from non-JWT access tokens. If not provided, user ID is extracted
  /// from JWT claims (sub, user_id, uid).
  const UserCacheKeyBuilder({
    this.userIdProvider,
  });

  /// Custom user ID provider for non-JWT authentication.
  final Future<String?> Function(String accessToken)? userIdProvider;

  /// Builds a cache key with user isolation for authenticated requests.
  ///
  /// Returns `null` if user cannot be identified, which disables caching.
  ///
  /// Process:
  /// 1. Extract Authorization header from request
  /// 2. Extract user ID from token (JWT or custom provider)
  /// 3. Build cache key with user ID: `{method}:{url}:{userId}`
  /// 4. Return null if no user ID available (disables caching)
  ///
  /// IMPORTANT: Caching is disabled for unauthenticated requests or
  /// when user ID cannot be extracted. This ensures all cached data
  /// is properly isolated by user.
  Future<String?> build(RequestOptions options) async {
    // Extract Authorization header
    final authHeader = options.headers['Authorization']?.toString();
    if (authHeader == null || authHeader.isEmpty) {
      // No authentication - disable caching
      return null;
    }

    // Extract token (handle "Bearer token" format)
    final token = _extractToken(authHeader);
    if (token == null) {
      // No token - disable caching
      return null;
    }

    // Get user ID from token
    final userId = await _extractUserId(token);
    if (userId == null || userId.isEmpty) {
      // No user ID - disable caching to prevent data leakage
      return null;
    }

    // Get standard cache key (method + URL)
    final baseKey = CacheOptions.defaultCacheKeyBuilder(options);

    // Return user-isolated cache key
    return '$baseKey:$userId';
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

  /// Extracts user ID from access token.
  ///
  /// Uses custom provider if available, otherwise extracts from JWT.
  Future<String?> _extractUserId(String token) async {
    // Try custom user ID provider first
    if (userIdProvider != null) {
      try {
        return await userIdProvider!(token);
      } on Exception catch (_) {
        // Custom provider failed - fall back to JWT extraction
      }
    }

    // Extract from JWT
    return JwtUtils.extractUserId(token);
  }
}
