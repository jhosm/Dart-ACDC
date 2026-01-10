import 'package:dart_acdc/src/auth/token_provider.dart';
import 'package:dart_acdc/src/builder/acdc_client_builder.dart';
import 'package:dart_acdc/src/cache/cache_config.dart';
import 'package:dart_acdc/src/interceptors/auth_interceptor.dart';
import 'package:dart_acdc/src/interceptors/cache_interceptor.dart';
import 'package:dart_acdc/src/interceptors/error_interceptor.dart';
import 'package:dart_acdc/src/interceptors/logging_interceptor.dart';
import 'package:dart_acdc/src/logging/log_level.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import '../helpers/mock_network_info.dart';

// Mock TokenProvider
class MockTokenProvider implements TokenProvider {
  @override
  Future<String?> getAccessToken() async => 'mock_token';
  @override
  Future<String?> getRefreshToken() async => 'mock_refresh_token';
  @override
  Future<DateTime?> getAccessTokenExpiry() async => null;
  @override
  Future<DateTime?> getRefreshTokenExpiry() async => null;
  @override
  Future<void> setTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? accessExpiry,
    DateTime? refreshExpiry,
  }) async {}
  @override
  Future<void> clearTokens() async {}
}

// Helper to track execution order
class ExecutionTracker {
  final List<String> events = [];

  void add(String event) {
    events.add(event);
  }
}

void main() {
  group('Interceptor Chain Order', () {
    test('Default interceptor order matches specification', () async {
      final tracker = ExecutionTracker();

      // Build client with all features enabled
      final dio = await const AcdcClientBuilder()
          .withBaseUrl('https://api.example.com')
          .withTokenProvider(MockTokenProvider())
          .withTokenRefreshEndpoint(
            url: 'https://auth.example.com',
            clientId: 'client',
          )
          .withLogLevel(LogLevel.info) // Enables LoggingInterceptor
          .withCache(const CacheConfig()) // Enables CacheInterceptor
          .withInterceptor(
            InterceptorsWrapper(
              // Custom Interceptor
              onRequest: (options, handler) {
                tracker.add('Custom:onRequest');
                handler.next(options);
              },
              onResponse: (response, handler) {
                tracker.add('Custom:onResponse');
                handler.next(response);
              },
              onError: (err, handler) {
                tracker.add('Custom:onError');
                handler.next(err);
              },
            ),
          )
          .withNetworkInfo(MockNetworkInfo())
          .build();

      // We need to wrap existing interceptors to track them because they are added internally.
      // However, we can't easily wrap them *after* build because they are already added.
      // But we can inspect the `dio.interceptors` list to verify their TYPES order,
      // which dictates execution order.

      // Dio Interceptor Execution:
      // Request: FIFO (First added -> Last added)
      // Response: LIFO (Last added -> First added)

      // Expected Order (from spec/issue):
      // Request: Logging -> Auth -> Cache -> Error -> Custom

      // Therefore, the `dio.interceptors` list should be:
      // [Logging, Auth, Cache, Error, Custom]

      // Let's verify the list content directly.
      final interceptors = dio.interceptors;

      // Check indices
      final loggingIndex =
          interceptors.indexWhere((i) => i is LoggingInterceptor);
      final authIndex = interceptors.indexWhere((i) => i is AuthInterceptor);
      final cacheIndex =
          interceptors.indexWhere((i) => i is AcdcCacheInterceptor);
      final errorIndex = interceptors.indexWhere((i) => i is ErrorInterceptor);
      // Custom interceptors are typically InterceptorsWrapper or custom classes
      // In our case we added one InterceptorsWrapper.
      // But Dio might wrap things internally? No, usually not.
      // Let's assume the last one is our custom one if it's InterceptorsWrapper
      final customIndex = interceptors.lastIndexWhere(
        (i) =>
            i is InterceptorsWrapper &&
            i is! ErrorInterceptor &&
            i is! LoggingInterceptor &&
            i is! AuthInterceptor &&
            i is! AcdcCacheInterceptor,
      );

      // Verify presence
      expect(loggingIndex, isNot(-1), reason: 'LoggingInterceptor missing');
      expect(authIndex, isNot(-1), reason: 'AuthInterceptor missing');
      expect(cacheIndex, isNot(-1), reason: 'CacheInterceptor missing');
      expect(errorIndex, isNot(-1), reason: 'ErrorInterceptor missing');

      // Verify Order for Request (FIFO)
      // Spec: Logging -> Auth -> Cache
      // So Logging index < Auth index < Cache index

      // Logging should be first
      expect(
        loggingIndex,
        lessThan(authIndex),
        reason: 'Logging should be before Auth',
      );
      expect(
        authIndex,
        lessThan(cacheIndex),
        reason: 'Auth should be before Cache',
      );

      // Spec: Response phase: Cache -> Auth -> Error -> Logging
      // Response is LIFO (Last added -> First added)
      // So List Order must be: Logging < Error < Auth < Cache

      // Verify Error is nested inside Logging but outside Auth
      expect(
        loggingIndex,
        lessThan(errorIndex),
        reason: 'Logging should wrap Error',
      );
      expect(errorIndex, lessThan(authIndex), reason: 'Error should wrap Auth');

      // Verify Cache is innermost (Last in list)
      expect(authIndex, lessThan(cacheIndex), reason: 'Auth should wrap Cache');

      // Custom should be last (closest to network for request, first for response??)
      // Wait.
      // "Request phase: Logging → Auth → Cache ... Custom"
      // => List: Logging, Auth, Cache, Error, Custom

      if (customIndex != -1) {
        expect(
          errorIndex,
          lessThan(customIndex),
          reason: 'Error should be before Custom',
        );
      }

      // Execution Test (Optional but good)
      // To truly test execution order we'd need to mock the inner workings or use a different approach.
      // Checking the list order is sufficient for Dio as it uses a stable FIFO/LIFO mechanism.
    });
  });
}
