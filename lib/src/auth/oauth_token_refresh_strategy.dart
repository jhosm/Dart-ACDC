import 'dart:io';

import 'package:dart_acdc/src/auth/token_refresh_result.dart';
import 'package:dart_acdc/src/auth/token_refresh_strategy.dart';
import 'package:dart_acdc/src/exceptions/acdc_auth_exception.dart';
import 'package:dart_acdc/src/exceptions/acdc_network_exception.dart';
import 'package:dart_acdc/src/exceptions/acdc_server_exception.dart';
import 'package:dio/dio.dart';

/// OAuth 2.1 token refresh strategy implementation.
///
/// Performs token refresh using the OAuth 2.1 refresh token grant flow.
/// Supports:
/// - Standard OAuth 2.1 token endpoint requests
/// - Token rotation (new refresh tokens in response)
/// - Clock skew handling using server Date header
/// - OAuth error code mapping
///
/// **Example:**
/// ```dart
/// final strategy = OAuthTokenRefreshStrategy(
///   refreshEndpointUrl: 'https://auth.example.com/oauth/token',
///   clientId: 'my-client-id',
/// );
///
/// final result = await strategy.refresh(refreshToken);
/// ```
class OAuthTokenRefreshStrategy implements TokenRefreshStrategy {
  /// Creates an OAuth token refresh strategy.
  ///
  /// [refreshEndpointUrl] is the OAuth token endpoint URL.
  /// [clientId] is the OAuth client identifier.
  /// [httpClient] is optional and primarily used for testing.
  ///   If not provided, a separate Dio instance will be created.
  OAuthTokenRefreshStrategy({
    required String refreshEndpointUrl,
    required String clientId,
    Dio? httpClient,
  })  : _refreshEndpointUrl = refreshEndpointUrl,
        _clientId = clientId,
        _httpClient = httpClient;

  final String _refreshEndpointUrl;
  final String _clientId;
  final Dio? _httpClient;

  @override
  Future<TokenRefreshResult> refresh(String refreshToken) async {
    // Use injected client or create a separate instance to avoid interceptor loops
    final dio = _httpClient ?? Dio();

    try {
      final response = await dio.post<Map<String, dynamic>>(
        _refreshEndpointUrl,
        data: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': _clientId,
        },
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          headers: {'Accept': 'application/json'},
        ),
      );

      final data = response.data!;

      // Extract tokens
      final accessToken = data['access_token'] as String?;
      if (accessToken == null) {
        throw AcdcAuthException(
          requestOptions: RequestOptions(path: _refreshEndpointUrl),
          message: 'Refresh response missing access_token',
        );
      }

      final newRefreshToken = data['refresh_token'] as String?;
      final expiresIn = data['expires_in'] as int?;

      // Calculate expiry with clock skew handling
      DateTime? accessExpiry;
      if (expiresIn != null) {
        // Try to use server time from Date header
        final dateHeader = response.headers.value('date');
        if (dateHeader != null) {
          try {
            // Parse HTTP date format (RFC 1123)
            final serverTime = HttpDate.parse(dateHeader);
            accessExpiry = serverTime.add(Duration(seconds: expiresIn));
          } on HttpException {
            // Fall back to local time if parsing fails
            accessExpiry =
                DateTime.now().toUtc().add(Duration(seconds: expiresIn));
          }
        } else {
          // No Date header - use local time
          accessExpiry =
              DateTime.now().toUtc().add(Duration(seconds: expiresIn));
        }
      }

      return TokenRefreshResult(
        accessToken: accessToken,
        refreshToken: newRefreshToken,
        accessExpiry: accessExpiry,
      );
    } on DioException catch (e) {
      // Handle OAuth error responses
      if (e.response?.statusCode == 400) {
        final data = e.response?.data;
        if (data is Map<String, dynamic>) {
          final error = data['error'] as String?;
          final errorDescription = data['error_description'] as String?;

          var message = _mapOAuthError(error);
          if (errorDescription != null) {
            message += ': $errorDescription';
          }

          throw AcdcAuthException.fromDioException(e, message: message);
        }
      }

      // Handle server errors (5xx)
      if (e.response?.statusCode != null && e.response!.statusCode! >= 500) {
        throw AcdcServerException.fromDioException(e);
      }

      // Handle network errors
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown) {
        throw AcdcNetworkException.fromDioException(e);
      }

      // Other errors
      rethrow;
    }
  }

  /// Maps OAuth error codes to user-friendly messages.
  String _mapOAuthError(String? error) {
    switch (error) {
      case 'invalid_grant':
        return 'Refresh token expired or invalid. Please log in again.';
      case 'invalid_client':
        return 'Client authentication failed. Check client configuration.';
      case 'unauthorized_client':
        return 'Client not authorized for token refresh.';
      case 'unsupported_grant_type':
        return 'Server does not support refresh token grant.';
      default:
        return 'Token refresh failed';
    }
  }
}
