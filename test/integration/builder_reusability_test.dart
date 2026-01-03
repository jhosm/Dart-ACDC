import 'package:dart_acdc/dart_acdc.dart';
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:test/test.dart';

import '../helpers/fake_token_provider.dart';

void main() {
  group('Builder Reusability Integration', () {
    late AcdcClientBuilder builder;

    setUp(() {
      builder = const AcdcClientBuilder()
          .withBaseUrl('https://api.example.com')
          .withTokenProvider(FakeTokenProvider())
          .withTimeout(const Duration(seconds: 5));
    });

    test('builds independent Dio instances', () async {
      final client1 = await builder.build();
      final client2 = await builder.build();

      // Verify they are different instances
      expect(client1, isNot(same(client2)));

      // Verify they share initial configuration
      expect(client1.options.baseUrl, 'https://api.example.com');
      expect(client2.options.baseUrl, 'https://api.example.com');

      // Modify client1
      client1.options.baseUrl = 'https://api.changed.com';
      client1.interceptors.add(InterceptorsWrapper());

      // Verify client2 is unaffected
      expect(client2.options.baseUrl, 'https://api.example.com');
      expect(
        client2.interceptors.length,
        isNot(equals(client1.interceptors.length)),
      );
    });

    test('clients work independently', () async {
      final client1 = await builder.build();
      final client2 = await builder.build();

      final adapter1 = DioAdapter(dio: client1);
      final adapter2 = DioAdapter(dio: client2);

      adapter1.onGet('/test', (server) => server.reply(200, {'id': 1}));
      adapter2.onGet('/test', (server) => server.reply(200, {'id': 2}));

      final response1 = await client1.get<dynamic>('/test');
      final response2 = await client2.get<dynamic>('/test');

      expect((response1.data as Map)['id'], 1);
      expect((response2.data as Map)['id'], 2);
    });
  });
}
