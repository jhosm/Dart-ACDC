import 'package:dart_acdc/dart_acdc.dart';

/// Basic example demonstrating dart_acdc usage
Future<void> main() async {
  // Example 1: Zero-config client
  await basicExample();

  // Example 2: With authentication
  await authExample();

  // Example 3: With caching
  await cachingExample();

  // Example 4: With custom logging
  await loggingExample();

  // Example 5: With custom token provider
  await customTokenProviderExample();
}

/// Example 1: Basic HTTP client
Future<void> basicExample() async {
  // Create a zero-config HTTP client
  final dio = await const AcdcClientBuilder().build();

  try {
    // Make a GET request
    final response = await dio.get<Map<String, dynamic>>(
      'https://api.example.com/data',
    );
    // Response data available in response.data
    final data = response.data;
    assert(data != null, 'Response data should not be null');
  } on AcdcException catch (e) {
    // Handle errors
    final message = e.message;
    assert(message.isNotEmpty, 'Error message should not be empty');
  }
}

/// Example 2: Client with authentication
Future<void> authExample() async {
  // Configure client with automatic token refresh
  final dio = await const AcdcClientBuilder()
      .withBaseUrl('https://api.example.com')
      .withTokenRefreshEndpoint(
        url: 'https://api.example.com/oauth/token',
        clientId: 'your-client-id',
      )
      .withInitialTokens(
        accessToken: 'initial-access-token',
        refreshToken: 'initial-refresh-token',
      )
      .build();

  try {
    // Tokens are automatically injected and refreshed
    final response = await dio.get<Map<String, dynamic>>('/protected');
    final data = response.data;
    assert(data != null, 'Response data should not be null');

    // Logout when done
    await dio.auth.logout();
  } on AcdcAuthException catch (e) {
    // Handle auth errors
    final message = e.message;
    assert(message.isNotEmpty, 'Error message should not be empty');
  }
}

/// Example 3: Client with caching
Future<void> cachingExample() async {
  // Configure client with caching (1 hour default TTL)
  final dio =
      await const AcdcClientBuilder().withCache(const CacheConfig()).build();

  // First request - fetches from network
  final response1 = await dio.get<Map<String, dynamic>>(
    'https://api.example.com/data',
  );
  final source1 = response1.extra['acdc_source']; // 'network'
  assert(source1 != null, 'Source should not be null');

  // Second request - served from cache
  final response2 = await dio.get<Map<String, dynamic>>(
    'https://api.example.com/data',
  );
  final source2 = response2.extra['acdc_source']; // 'cache'
  assert(source2 != null, 'Source should not be null');
}

/// Example 4: Client with custom logging
Future<void> loggingExample() async {
  // Configure client with custom log delegate
  final dio = await const AcdcClientBuilder()
      .withLogLevel(LogLevel.debug)
      .withLogDelegate(MyLogDelegate())
      .build();

  await dio.get<Map<String, dynamic>>('https://api.example.com/data');
  // Logs will be sent to MyLogDelegate
}

/// Example 5: Client with custom token provider
Future<void> customTokenProviderExample() async {
  // Use custom token storage
  final dio = await const AcdcClientBuilder()
      .withTokenProvider(MyTokenProvider())
      .withTokenRefreshEndpoint(
        url: 'https://api.example.com/oauth/token',
        clientId: 'your-client-id',
      )
      .build();

  await dio.get<Map<String, dynamic>>('https://api.example.com/protected');
}

/// Example token provider implementation
class MyTokenProvider implements TokenProvider {
  @override
  Future<String?> getAccessToken() async =>
      // Retrieve access token from your storage
      'your-access-token';

  @override
  Future<String?> getRefreshToken() async =>
      // Retrieve refresh token from your storage
      'your-refresh-token';

  @override
  Future<DateTime?> getAccessTokenExpiry() async =>
      // Retrieve access token expiry from your storage
      DateTime.now().add(const Duration(hours: 1));

  @override
  Future<DateTime?> getRefreshTokenExpiry() async =>
      // Retrieve refresh token expiry from your storage
      DateTime.now().add(const Duration(days: 30));

  @override
  Future<void> setTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? accessExpiry,
    DateTime? refreshExpiry,
  }) async {
    // Save tokens to your storage
  }

  @override
  Future<void> clearTokens() async {
    // Clear tokens from your storage
  }
}

/// Example log delegate implementation
class MyLogDelegate implements AcdcLogDelegate {
  @override
  void log(String message, LogLevel level, [Map<String, dynamic>? metadata]) {
    // Send logs to your logging system
    // In production, use a proper logging framework
  }
}
