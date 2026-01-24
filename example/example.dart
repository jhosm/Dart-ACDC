import 'package:dart_acdc/dart_acdc.dart';
import 'package:dio/dio.dart';

/// Simple example demonstrating basic usage of dart_acdc
void main() async {
  // Create a zero-config HTTP client
  final dio = AcdcClientBuilder().build();

  try {
    // Make a GET request
    final response = await dio.get<Map<String, dynamic>>(
      'https://api.example.com/data',
    );
    print('Response: ${response.data}');
  } on AcdcException catch (e) {
    print('Error: ${e.message}');
  }
}

/// Example with authentication
void authExample() async {
  // Configure client with authentication
  final dio = AcdcClientBuilder()
      .withAuth(
        tokenProvider: MyTokenProvider(),
        refreshUrl: 'https://api.example.com/auth/refresh',
      )
      .build();

  try {
    final response = await dio.get<Map<String, dynamic>>(
      'https://api.example.com/protected',
    );
    print('Protected data: ${response.data}');
  } on AcdcAuthException catch (e) {
    print('Auth error: ${e.message}');
  }
}

/// Example with caching
void cachingExample() async {
  // Configure client with caching
  final dio = AcdcClientBuilder()
      .withCache(
        enabled: true,
        maxAge: const Duration(hours: 1),
      )
      .build();

  // First request - fetches from network
  final response1 = await dio.get<Map<String, dynamic>>(
    'https://api.example.com/data',
  );
  print('Source: ${response1.extra['acdc_source']}'); // 'network'

  // Second request - served from cache
  final response2 = await dio.get<Map<String, dynamic>>(
    'https://api.example.com/data',
  );
  print('Source: ${response2.extra['acdc_source']}'); // 'cache'
}

/// Example with custom logging
void loggingExample() async {
  // Configure client with custom logging
  final dio = AcdcClientBuilder()
      .withLogging(
        logDelegate: MyLogDelegate(),
        enableInProduction: false,
      )
      .build();

  await dio.get<Map<String, dynamic>>('https://api.example.com/data');
}

/// Example token provider implementation
class MyTokenProvider implements AcdcTokenProvider {
  @override
  Future<String?> getAccessToken() async {
    // Retrieve access token from secure storage
    return 'your-access-token';
  }

  @override
  Future<String?> getRefreshToken() async {
    // Retrieve refresh token from secure storage
    return 'your-refresh-token';
  }

  @override
  Future<void> saveTokens({
    required String? accessToken,
    required String? refreshToken,
  }) async {
    // Save tokens to secure storage
  }

  @override
  Future<void> clearTokens() async {
    // Clear tokens from secure storage
  }
}

/// Example log delegate implementation
class MyLogDelegate implements AcdcLogDelegate {
  @override
  void log(String message, LogLevel level, [Map<String, dynamic>? metadata]) {
    print('[$level] $message');
    if (metadata != null) {
      print('Metadata: $metadata');
    }
  }
}
