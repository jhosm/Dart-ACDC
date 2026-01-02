import 'package:dio/dio.dart';

/// Helper class providing utility methods for authentication request manipulation.
///
/// This class contains static methods to reduce code duplication in authentication
/// interceptors, particularly for common operations like:
/// - Creating empty RequestOptions
/// - Injecting Bearer tokens
/// - Checking for existing auth headers
/// - Managing retry flags
class AuthRequestHelper {
  // Private constructor to prevent instantiation
  AuthRequestHelper._();

  /// Creates an empty RequestOptions instance.
  ///
  /// Used when creating exceptions that don't have an associated request.
  static RequestOptions createEmptyRequestOptions() => RequestOptions();

  /// Injects a Bearer token into the request's Authorization header.
  ///
  /// Example:
  /// ```dart
  /// AuthRequestHelper.injectBearerToken(options, 'my-access-token');
  /// // options.headers['Authorization'] == 'Bearer my-access-token'
  /// ```
  static void injectBearerToken(RequestOptions options, String token) {
    options.headers['Authorization'] = 'Bearer $token';
  }

  /// Checks if the request already has a manual Authorization header.
  ///
  /// Returns `true` if an Authorization header exists (user override),
  /// `false` otherwise.
  static bool hasManualAuthHeader(RequestOptions options) =>
      options.headers.containsKey('Authorization');

  /// Marks a request as a retry attempt after token refresh.
  ///
  /// This flag prevents infinite retry loops by indicating the request
  /// has already been retried once with a refreshed token.
  static void markAsRetry(RequestOptions options) {
    options.extra['_acdc_retry_after_refresh'] = true;
  }

  /// Checks if a request is a retry attempt after token refresh.
  ///
  /// Returns `true` if the request was already retried with a refreshed token,
  /// `false` otherwise.
  static bool isRetryRequest(RequestOptions options) =>
      options.extra['_acdc_retry_after_refresh'] == true;
}
