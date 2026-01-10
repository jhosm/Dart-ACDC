import 'package:dart_acdc/dart_acdc.dart';
import 'package:test/test.dart';

import '../helpers/fake_token_provider.dart';
import '../helpers/mock_network_info.dart';

// Create a mock class for TokenProvider

void main() {
  group('AcdcClientBuilder withInitialTokens', () {
    late FakeTokenProvider tokenProvider;

    setUp(() {
      tokenProvider = FakeTokenProvider();
      // Register fallback value for DateTime if needed, mostly explicit here
    });

    test('initial tokens are stored in provided TokenProvider', () async {
      final now = DateTime.now().toUtc();
      final accessExpiry = now.add(const Duration(hours: 1));
      final refreshExpiry = now.add(const Duration(days: 30));

      final builder = const AcdcClientBuilder()
          .withBaseUrl('https://api.example.com')
          .withTokenProvider(tokenProvider)
          .withInitialTokens(
            accessToken: 'initial-access',
            refreshToken: 'initial-refresh',
            accessExpiry: accessExpiry,
            refreshExpiry: refreshExpiry,
          )
          .withNetworkInfo(MockNetworkInfo());

      await builder.build();

      // Verify tokens were set on the provider
      expect(await tokenProvider.getAccessToken(), 'initial-access');
      expect(await tokenProvider.getRefreshToken(), 'initial-refresh');
      expect(await tokenProvider.getAccessTokenExpiry(), accessExpiry);
      expect(await tokenProvider.getRefreshTokenExpiry(), refreshExpiry);
    });

    test('build waits for token storage complete', () async {
      // Create a slow token provider to verify await behavior
      final slowProvider = SlowTokenProvider();

      final builder = const AcdcClientBuilder()
          .withBaseUrl('https://api.example.com')
          .withTokenProvider(slowProvider)
          .withInitialTokens(
            accessToken: 'initial-access',
          )
          .withNetworkInfo(MockNetworkInfo());

      final stopwatch = Stopwatch()..start();
      await builder.build();
      stopwatch.stop();

      // Should take at least 100ms (simulated delay)
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(100));
      expect(slowProvider.tokensSet, isTrue);
    });
  });
}

class SlowTokenProvider extends FakeTokenProvider {
  bool tokensSet = false;

  @override
  Future<void> setTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? accessExpiry,
    DateTime? refreshExpiry,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await super.setTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessExpiry: accessExpiry,
      refreshExpiry: refreshExpiry,
    );
    tokensSet = true;
  }
}
