import 'package:dart_acdc/dart_acdc.dart';
import 'package:dart_acdc/src/extensions/acdc_client_extensions.dart';
import 'package:dart_acdc/src/network_info/network_info.dart';
import 'package:dio/dio.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:test/test.dart';

import 'acdc_client_extensions_test.mocks.dart';

@GenerateMocks([NetworkInfo])
void main() {
  group('AcdcClientExtensions', () {
    late Dio dio;
    late MockNetworkInfo mockNetworkInfo;

    setUp(() {
      dio = Dio();
      mockNetworkInfo = MockNetworkInfo();
    });

    test('networkInfo returns null when not configured', () {
      expect(dio.networkInfo, isNull);
    });

    test('networkInfo returns configured instance', () {
      dio.options.extra['_acdc_network_info'] = mockNetworkInfo;
      expect(dio.networkInfo, same(mockNetworkInfo));
    });

    test('closeAcdc disposes networkInfo', () {
      dio.options.extra['_acdc_network_info'] = mockNetworkInfo;

      dio.closeAcdc(); // Should call dispose

      verify(mockNetworkInfo.dispose()).called(1);
    });

    test('closeAcdc calls dio.close', () {
      // We can't easily verify dio.close() on a real Dio instance as it's not mocked here,
      // but we can check if it throws or behaves expectedly.
      // closeAcdc calls close().

      dio.options.extra['_acdc_network_info'] = mockNetworkInfo;

      expect(() => dio.closeAcdc(), returnsNormally);

      // Dio doesn't expose 'closed' state easily without checking internal adapter or making request.
      // But purely from extension logic, we just want to ensure it passes through.
    });

    group('streamRequest', () {
      test('emits single response when SWR is not triggered', () async {
        dio.httpClientAdapter = MockAdapter((options) async {
          return ResponseBody.fromString(
            '{"data": "fresh"}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType]
            },
          );
        });

        final stream = dio.streamRequest<Map<String, dynamic>>('/test');

        final responses = await stream.toList();
        expect(responses, hasLength(1));
        expect(responses.first.data!['data'], 'fresh');
      });

      test('emits cached and fresh response when SWR callback is triggered',
          () async {
        // Simulate Interceptor behavior via Adapter (simplified)
        // In reality, Interceptor runs swr_callback, and Adapter handles requests.
        dio.httpClientAdapter = MockAdapter((options) async {
          // Check if this is the initial request or background refresh
          // But streamRequest logic adds swr_callback to initial request.

          final swrCallback =
              options.extra['swr_callback'] as void Function(Future<dynamic>)?;

          if (swrCallback != null) {
            // This mocks the Interceptor finding a cached response, serving it,
            // and triggering background refresh.

            // 2. Trigger background refresh via callback
            // The callback expects a Future (the background request).
            // We simulate the background request completing later.
            final backgroundFuture =
                Future.delayed(Duration(milliseconds: 50), () {
              return Response<Map<String, dynamic>>(
                requestOptions: RequestOptions(path: '/test'),
                data: {'data': 'fresh'},
                statusCode: 200,
              );
            });

            swrCallback(backgroundFuture);

            // 1. Return "Cached" response immediately
            return ResponseBody.fromString(
              '{"data": "cached"}',
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType]
              },
            );
          }

          return ResponseBody.fromString('{"data": "normal"}', 200, headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          });
        });

        final stream = dio.streamRequest<Map<String, dynamic>>('/test');

        final responses = await stream.toList();
        expect(responses, hasLength(2));
        expect(responses[0].data!['data'], 'cached');
        expect(responses[1].data!['data'], 'fresh');
      });

      test('emits error from background refresh', () async {
        dio.httpClientAdapter = MockAdapter((options) async {
          final swrCallback =
              options.extra['swr_callback'] as void Function(Future<dynamic>)?;
          if (swrCallback != null) {
            final backgroundFuture =
                Future.delayed(Duration(milliseconds: 10), () {
              throw DioException(
                  requestOptions: options, error: 'Background error');
            });
            swrCallback(backgroundFuture);

            return ResponseBody.fromString('{"data": "cached"}', 200, headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType]
            });
          }
          return ResponseBody.fromString('{}', 200);
        });

        final stream = dio.streamRequest<Map<String, dynamic>>('/test');

        // Should emit cached then error
        bool cachedReceived = false;
        bool errorReceived = false;
        try {
          await for (final response in stream) {
            if (!cachedReceived) {
              expect(response.data!['data'], 'cached');
              cachedReceived = true;
            } else {
              fail('Should not receive second response, expecting error');
            }
          }
        } catch (e) {
          errorReceived = true;
          expect(e, isA<DioException>());
        }

        expect(cachedReceived, isTrue);
        expect(errorReceived, isTrue);
      });
    });
  });
}

class MockAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) handler;
  MockAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future? cancelFuture) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
