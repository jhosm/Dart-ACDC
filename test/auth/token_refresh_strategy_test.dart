import 'dart:io';

import 'package:dart_acdc/src/auth/custom_token_refresh_strategy.dart';
import 'package:dart_acdc/src/auth/oauth_token_refresh_strategy.dart';
import 'package:dart_acdc/src/auth/token_refresh_result.dart';
import 'package:dart_acdc/src/exceptions/acdc_auth_exception.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  group('OAuthTokenRefreshStrategy', () {
    test('successfully refreshes token with OAuth endpoint', () async {
      final mockDio = _createSuccessfulOAuthDio(
        accessToken: 'new-access-token',
        refreshToken: 'new-refresh-token',
        expiresIn: 3600,
      );

      final strategy = OAuthTokenRefreshStrategy(
        refreshEndpointUrl: 'https://auth.example.com/token',
        clientId: 'test-client',
        httpClient: mockDio,
      );

      final result = await strategy.refresh('old-refresh-token');

      expect(result.accessToken, 'new-access-token');
      expect(result.refreshToken, 'new-refresh-token');
      expect(result.accessExpiry, isNotNull);
    });

    test('refreshes token without new refresh token (no rotation)', () async {
      final mockDio = _createSuccessfulOAuthDio(
        accessToken: 'new-access-token',
        expiresIn: 3600,
      );

      final strategy = OAuthTokenRefreshStrategy(
        refreshEndpointUrl: 'https://auth.example.com/token',
        clientId: 'test-client',
        httpClient: mockDio,
      );

      final result = await strategy.refresh('refresh-token');

      expect(result.accessToken, 'new-access-token');
      expect(result.refreshToken, isNull);
      expect(result.accessExpiry, isNotNull);
    });

    test('refreshes token without expiry information', () async {
      final mockDio = _createSuccessfulOAuthDio(
        accessToken: 'new-access-token',
      );

      final strategy = OAuthTokenRefreshStrategy(
        refreshEndpointUrl: 'https://auth.example.com/token',
        clientId: 'test-client',
        httpClient: mockDio,
      );

      final result = await strategy.refresh('refresh-token');

      expect(result.accessToken, 'new-access-token');
      expect(result.accessExpiry, isNull);
    });

    test('uses server time from Date header for expiry calculation', () async {
      final serverTime = DateTime.utc(2024, 1, 1, 12);
      final mockDio = _createSuccessfulOAuthDio(
        accessToken: 'new-access-token',
        expiresIn: 3600,
        serverTime: HttpDate.format(serverTime),
      );

      final strategy = OAuthTokenRefreshStrategy(
        refreshEndpointUrl: 'https://auth.example.com/token',
        clientId: 'test-client',
        httpClient: mockDio,
      );

      final result = await strategy.refresh('refresh-token');

      expect(result.accessToken, 'new-access-token');
      expect(result.accessExpiry, serverTime.add(const Duration(hours: 1)));
    });

    test('falls back to local time when Date header is invalid', () async {
      final mockDio = _createSuccessfulOAuthDio(
        accessToken: 'new-access-token',
        expiresIn: 3600,
        serverTime: 'invalid-date-format',
      );

      final strategy = OAuthTokenRefreshStrategy(
        refreshEndpointUrl: 'https://auth.example.com/token',
        clientId: 'test-client',
        httpClient: mockDio,
      );

      final result = await strategy.refresh('refresh-token');

      expect(result.accessToken, 'new-access-token');
      expect(result.accessExpiry, isNotNull);
      // Expiry should be roughly now + 1 hour since it falls back to local time
      final now = DateTime.now().toUtc();
      final expectedExpiry = now.add(const Duration(hours: 1));
      expect(
        result.accessExpiry!.difference(expectedExpiry).inSeconds.abs(),
        lessThan(5), // Allow 5 second tolerance for test execution time
      );
    });

    test('throws AcdcAuthException when access_token is missing', () async {
      final mockDio = _createInvalidOAuthDio();

      final strategy = OAuthTokenRefreshStrategy(
        refreshEndpointUrl: 'https://auth.example.com/token',
        clientId: 'test-client',
        httpClient: mockDio,
      );

      expect(
        () => strategy.refresh('refresh-token'),
        throwsA(isA<AcdcAuthException>()),
      );
    });

    test('handles invalid_grant OAuth error', () async {
      final mockDio = _createOAuthErrorDio(
        'invalid_grant',
        'Refresh token expired',
      );

      final strategy = OAuthTokenRefreshStrategy(
        refreshEndpointUrl: 'https://auth.example.com/token',
        clientId: 'test-client',
        httpClient: mockDio,
      );

      expect(
        () => strategy.refresh('expired-token'),
        throwsA(
          isA<AcdcAuthException>().having(
            (e) => e.message,
            'message',
            contains('Refresh token expired or invalid'),
          ),
        ),
      );
    });

    test('handles invalid_client OAuth error', () async {
      final mockDio = _createOAuthErrorDio(
        'invalid_client',
        'Client authentication failed',
      );

      final strategy = OAuthTokenRefreshStrategy(
        refreshEndpointUrl: 'https://auth.example.com/token',
        clientId: 'invalid-client',
        httpClient: mockDio,
      );

      expect(
        () => strategy.refresh('refresh-token'),
        throwsA(
          isA<AcdcAuthException>().having(
            (e) => e.message,
            'message',
            contains('Client authentication failed'),
          ),
        ),
      );
    });

    test('handles unauthorized_client OAuth error', () async {
      final mockDio = _createOAuthErrorDio(
        'unauthorized_client',
        'Client not authorized',
      );

      final strategy = OAuthTokenRefreshStrategy(
        refreshEndpointUrl: 'https://auth.example.com/token',
        clientId: 'test-client',
        httpClient: mockDio,
      );

      expect(
        () => strategy.refresh('refresh-token'),
        throwsA(
          isA<AcdcAuthException>().having(
            (e) => e.message,
            'message',
            contains('Client not authorized for token refresh'),
          ),
        ),
      );
    });

    test('handles unsupported_grant_type OAuth error', () async {
      final mockDio = _createOAuthErrorDio(
        'unsupported_grant_type',
        'Grant type not supported',
      );

      final strategy = OAuthTokenRefreshStrategy(
        refreshEndpointUrl: 'https://auth.example.com/token',
        clientId: 'test-client',
        httpClient: mockDio,
      );

      expect(
        () => strategy.refresh('refresh-token'),
        throwsA(
          isA<AcdcAuthException>().having(
            (e) => e.message,
            'message',
            contains('Server does not support refresh token grant'),
          ),
        ),
      );
    });

    test('handles unknown OAuth error code', () async {
      final mockDio = _createOAuthErrorDio(
        'unknown_error',
        'Some error',
      );

      final strategy = OAuthTokenRefreshStrategy(
        refreshEndpointUrl: 'https://auth.example.com/token',
        clientId: 'test-client',
        httpClient: mockDio,
      );

      expect(
        () => strategy.refresh('refresh-token'),
        throwsA(
          isA<AcdcAuthException>().having(
            (e) => e.message,
            'message',
            contains('Token refresh failed'),
          ),
        ),
      );
    });

    test('rethrows DioException for network errors', () async {
      final mockDio = Dio();
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionTimeout,
              ),
            );
          },
        ),
      );

      final strategy = OAuthTokenRefreshStrategy(
        refreshEndpointUrl: 'https://auth.example.com/token',
        clientId: 'test-client',
        httpClient: mockDio,
      );

      expect(
        () => strategy.refresh('refresh-token'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('CustomTokenRefreshStrategy', () {
    test('successfully refreshes token with custom function', () async {
      final strategy = CustomTokenRefreshStrategy(
        refreshFn: (refreshToken) async {
          expect(refreshToken, 'test-refresh-token');
          return const TokenRefreshResult(
            accessToken: 'custom-access-token',
            refreshToken: 'custom-refresh-token',
          );
        },
      );

      final result = await strategy.refresh('test-refresh-token');

      expect(result.accessToken, 'custom-access-token');
      expect(result.refreshToken, 'custom-refresh-token');
    });

    test('passes through exceptions from custom function', () async {
      final strategy = CustomTokenRefreshStrategy(
        refreshFn: (refreshToken) async {
          throw AcdcAuthException(
            requestOptions: RequestOptions(path: '/test'),
            message: 'Custom auth error',
          );
        },
      );

      expect(
        () => strategy.refresh('refresh-token'),
        throwsA(
          isA<AcdcAuthException>().having(
            (e) => e.message,
            'message',
            'Custom auth error',
          ),
        ),
      );
    });

    test('returns result without refresh token rotation', () async {
      final strategy = CustomTokenRefreshStrategy(
        refreshFn: (refreshToken) async => const TokenRefreshResult(
          accessToken: 'new-token',
        ),
      );

      final result = await strategy.refresh('refresh-token');

      expect(result.accessToken, 'new-token');
      expect(result.refreshToken, isNull);
    });

    test('returns result with expiry information', () async {
      final expiry = DateTime.now().toUtc().add(const Duration(hours: 1));

      final strategy = CustomTokenRefreshStrategy(
        refreshFn: (refreshToken) async => TokenRefreshResult(
          accessToken: 'new-token',
          accessExpiry: expiry,
        ),
      );

      final result = await strategy.refresh('refresh-token');

      expect(result.accessToken, 'new-token');
      expect(result.accessExpiry, expiry);
    });
  });
}

/// Creates a mock Dio instance that simulates successful OAuth refresh.
Dio _createSuccessfulOAuthDio({
  required String accessToken,
  String? refreshToken,
  int? expiresIn,
  String? serverTime,
}) {
  final dio = Dio();

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final responseData = <String, dynamic>{
          'access_token': accessToken,
        };

        if (refreshToken != null) {
          responseData['refresh_token'] = refreshToken;
        }

        if (expiresIn != null) {
          responseData['expires_in'] = expiresIn;
        }

        final headers = Headers();
        if (serverTime != null) {
          headers.add('date', serverTime);
        }

        handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 200,
            data: responseData,
            headers: headers,
          ),
        );
      },
    ),
  );

  return dio;
}

/// Creates a mock Dio instance that returns invalid response (missing access_token).
Dio _createInvalidOAuthDio() {
  final dio = Dio();

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 200,
            data: <String, dynamic>{}, // Missing access_token
          ),
        );
      },
    ),
  );

  return dio;
}

/// Creates a mock Dio instance that simulates OAuth error responses.
Dio _createOAuthErrorDio(String errorCode, String errorDescription) {
  final dio = Dio();

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(
          DioException(
            requestOptions: options,
            response: Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 400,
              data: {
                'error': errorCode,
                'error_description': errorDescription,
              },
            ),
            type: DioExceptionType.badResponse,
          ),
        );
      },
    ),
  );

  return dio;
}
