import 'package:dart_acdc/dart_acdc.dart';
import 'package:dart_acdc/src/extensions/acdc_client_extensions.dart';
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:test/test.dart';

import '../helpers/mock_network_info.dart';

void main() {
  group('cancelAll Integration', () {
    late Dio client;
    late DioAdapter adapter;

    setUp(() async {
      client = await AcdcClientBuilder()
          .withBaseUrl('https://example.com')
          .disableAuth()
          .disableCache()
          .withNetworkInfo(MockNetworkInfo())
          .build();
      adapter = DioAdapter(dio: client);
    });

    test('should cancel all pending requests', () async {
      // Setup delayed response
      adapter.onGet('/delayed', (server) {
        server.reply(200, {'data': 'ok'}, delay: const Duration(seconds: 5));
      });

      final errors = <DioException>[];

      // Helper to make a request and capture errors
      Future<void> makeRequest() async {
        try {
          await client.get('/delayed');
          fail('Request should have been cancelled');
        } on DioException catch (e) {
          errors.add(e);
        }
      }

      // Start 5 concurrent requests
      final futures = <Future<void>>[];
      for (int i = 0; i < 5; i++) {
        futures.add(makeRequest());
      }

      // Allow requests to be processed and added to tracker
      await Future.delayed(const Duration(milliseconds: 100));

      // Cancel all
      const reason = 'Integration test cancellation';
      client.cancelAll(reason);

      // Wait for all to complete (with error)
      await Future.wait(futures);

      expect(errors.length, 5);
      for (final error in errors) {
        expect(error.type, DioExceptionType.cancel);
        expect(error.error, reason);
      }

      // Verify tracker is empty
      expect(client.activeRequestTracker?.activeCount, 0);
    });

    test('should allow new requests after cancelAll', () async {
      adapter.onGet('/instant', (server) {
        server.reply(200, {'data': 'ok'});
      });

      client.cancelAll();

      final response = await client.get('/instant');
      expect(response.statusCode, 200);
      expect(client.activeRequestTracker?.activeCount,
          0); // Should be empty after success
    });
  });
}
