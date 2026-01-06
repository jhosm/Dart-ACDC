import 'package:dart_acdc/dart_acdc.dart';
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:test/test.dart';

import '../helpers/fake_token_provider.dart';

void main() {
  group('Custom Logger Integration', () {
    late Dio dio;
    late DioAdapter dioAdapter;
    late List<String> logs;

    setUp(() async {
      logs = [];

      // Define custom logger
      void customLogger(
        String message,
        LogLevel level,
        Map<String, dynamic>? metadata,
      ) {
        logs.add('[$level] $message');
        if (metadata != null && metadata.isNotEmpty) {
          logs.add('Metadata: $metadata');
        }
      }

      // Build client with custom logger
      dio = await const AcdcClientBuilder()
          .withBaseUrl('https://api.example.com')
          .withTokenProvider(FakeTokenProvider())
          .withLogger(customLogger)
          .withLogLevel(LogLevel.info)
          .disableCache()
          .build();

      dioAdapter = DioAdapter(dio: dio);
    });

    test('logs request and response with custom logger', () async {
      dioAdapter.onGet(
        '/test',
        (server) => server.reply(200, {'data': 'success'}),
      );

      await dio.get<dynamic>('/test');

      // Verify logs were captured
      // Note: Exact messages depend on implementation, but we expect at least request/response logs
      expect(
        logs,
        contains(
          contains(
            '[LogLevel.info] Request: GET https://api.example.com/test',
          ),
        ),
      );
      expect(
        logs,
        contains(
          contains(
            '[LogLevel.info] Response: 200 https://api.example.com/test',
          ),
        ),
      );
    });

    test('logs errors with custom logger', () async {
      dioAdapter.onGet(
        '/error',
        (server) => server.reply(500, {'error': 'server error'}),
      );

      try {
        await dio.get<dynamic>('/error');
      } on Object catch (_) {
        // Ignore error
      }

      // Verify error logs (updated to match enhanced error logging format)
      expect(
        logs,
        contains(
          contains(
            '[LogLevel.error] HTTP error 500: GET https://api.example.com/error',
          ),
        ),
      );
    });
  });
}
