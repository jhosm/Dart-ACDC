import 'package:dart_acdc/src/interceptors/deduplication_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'deduplication_interceptor_test.mocks.dart';

@GenerateMocks([
  RequestInterceptorHandler,
  ResponseInterceptorHandler,
  ErrorInterceptorHandler,
])
void main() {
  late DeduplicationInterceptor interceptor;
  late MockRequestInterceptorHandler requestHandler;
  late MockResponseInterceptorHandler responseHandler;
  late MockErrorInterceptorHandler errorHandler;

  setUp(() {
    interceptor = DeduplicationInterceptor();
    requestHandler = MockRequestInterceptorHandler();
    responseHandler = MockResponseInterceptorHandler();
    errorHandler = MockErrorInterceptorHandler();
  });

  group('DeduplicationInterceptor', () {
    test('should allow first request to proceed', () {
      final options = RequestOptions(path: '/test');
      interceptor.onRequest(options, requestHandler);
      verify(requestHandler.next(options)).called(1);
    });

    test('should deduplicate identical concurrent requests', () async {
      final options1 = RequestOptions(path: '/test');
      final options2 = RequestOptions(path: '/test');

      // First request proceeds
      interceptor.onRequest(options1, requestHandler);
      verify(requestHandler.next(options1)).called(1);

      // Second request waits (should NOT call next)
      interceptor.onRequest(options2, requestHandler);
      verifyNever(requestHandler.next(options2));
    });

    test('should NOT deduplicate different methods', () {
      final options1 = RequestOptions(path: '/test', method: 'GET');
      final options2 = RequestOptions(path: '/test', method: 'HEAD');

      interceptor.onRequest(options1, requestHandler);
      verify(requestHandler.next(options1)).called(1);

      interceptor.onRequest(options2, requestHandler);
      verify(requestHandler.next(options2)).called(1);
    });

    test('should NOT deduplicate non-idempotent methods', () {
      final options1 = RequestOptions(path: '/test', method: 'POST');
      final options2 = RequestOptions(path: '/test', method: 'POST');

      interceptor.onRequest(options1, requestHandler);
      verify(requestHandler.next(options1)).called(1);

      interceptor.onRequest(options2, requestHandler);
      verify(requestHandler.next(options2)).called(1);
    });

    test('should resolve waiting requests when primary completes', () async {
      final options1 = RequestOptions(path: '/test');
      final options2 = RequestOptions(path: '/test');

      // 1. Start primary
      // 1. Start primary
      interceptor
        ..onRequest(options1, requestHandler)
        // 2. Start secondary (deduplicated)
        ..onRequest(options2, requestHandler);

      // 3. Complete primary
      final response =
          Response(requestOptions: options1, data: 'data', statusCode: 200);
      interceptor.onResponse(response, responseHandler);

      // Verify primary pass-through
      verify(responseHandler.next(response)).called(1);

      // Verify secondary resolution (needs a small delay for Future to propagate)
      await Future<void>.delayed(Duration.zero);

      final verification = verify(requestHandler.resolve(captureAny))
        ..called(1);
      final resolvedResponse = verification.captured.first as Response;
      expect(resolvedResponse.data, 'data');
      expect(
        resolvedResponse.requestOptions,
        options2,
      ); // Should have its own options
    });

    test('should propagate error to waiting requests when primary fails',
        () async {
      final options1 = RequestOptions(path: '/test');
      final options2 = RequestOptions(path: '/test');

      interceptor
        ..onRequest(options1, requestHandler)
        ..onRequest(options2, requestHandler);

      final error = DioException(
        requestOptions: options1,
        type: DioExceptionType.connectionError,
      );
      interceptor.onError(error, errorHandler);

      verify(errorHandler.next(error)).called(1);

      await Future<void>.delayed(Duration.zero);
      verify(requestHandler.reject(any)).called(1);
    });

    test('should NOT deduplicate if stream response type', () {
      final options1 =
          RequestOptions(path: '/test', responseType: ResponseType.stream);
      final options2 =
          RequestOptions(path: '/test', responseType: ResponseType.stream);

      interceptor
        ..onRequest(options1, requestHandler)
        ..onRequest(options2, requestHandler);

      verify(requestHandler.next(options1)).called(1);
      verify(requestHandler.next(options2)).called(1);
    });

    test('should NOT deduplicate if explicit config disable', () {
      final options1 =
          RequestOptions(path: '/test', extra: {'deduplicate': false});
      final options2 =
          RequestOptions(path: '/test', extra: {'deduplicate': false});

      interceptor
        ..onRequest(options1, requestHandler)
        ..onRequest(options2, requestHandler);

      verify(requestHandler.next(options1)).called(1);
      verify(requestHandler.next(options2)).called(1);
    });

    test('secondary cancellation should NOT affect primary', () async {
      final options1 = RequestOptions(path: '/test');
      final cancelToken2 = CancelToken();
      final options2 = RequestOptions(path: '/test', cancelToken: cancelToken2);

      interceptor
        ..onRequest(options1, requestHandler)
        ..onRequest(options2, requestHandler);

      // Cancel secondary
      cancelToken2.cancel();
      await Future<void>.delayed(Duration.zero);

      // Verify secondary rejected
      verify(
        requestHandler.reject(
          argThat(
            predicate<DioException>(
              (e) => e.type == DioExceptionType.cancel,
            ),
          ),
        ),
      ).called(1);

      // Verify primary still active (no Response/Error called yet)
      verify(requestHandler.next(options1)).called(1);
      // And no cancellation signal sent to primary logic (which isn't mocked here but implied by logic)
    });

    test('should allow sequential identical requests (no deduplication)',
        () async {
      final options1 = RequestOptions(path: '/test');
      final options2 = RequestOptions(path: '/test');

      // 1. First request starts
      interceptor.onRequest(options1, requestHandler);
      verify(requestHandler.next(options1)).called(1);

      // 2. First request completes
      final response1 =
          Response(requestOptions: options1, data: 'data1', statusCode: 200);
      interceptor.onResponse(response1, responseHandler);
      verify(responseHandler.next(response1)).called(1);

      // 3. Second request starts (should NOT deduplicate)
      interceptor.onRequest(options2, requestHandler);
      verify(requestHandler.next(options2)).called(1);
    });

    test('primary cancellation should cancel/error waiting requests', () async {
      final cancelToken1 = CancelToken();
      final options1 = RequestOptions(path: '/test', cancelToken: cancelToken1);
      final options2 = RequestOptions(path: '/test');

      interceptor
        ..onRequest(options1, requestHandler)
        ..onRequest(options2, requestHandler);

      // Cancel primary
      // In real world, Dio cancels the token which triggers onError with Cancel exception
      final cancelError = DioException(
        requestOptions: options1,
        type: DioExceptionType.cancel,
        message: 'Primary cancelled',
      );

      // Simulate primary error flow due to cancellation
      interceptor.onError(cancelError, errorHandler);

      verify(errorHandler.next(cancelError)).called(1);

      await Future<void>.delayed(Duration.zero);

      // Waiting request should get the error too
      verify(
        requestHandler.reject(
          argThat(
            predicate<DioException>(
              (e) => e.type == DioExceptionType.cancel,
            ),
          ),
        ),
      ).called(1);
    });
  });
}
