import 'package:dart_acdc/src/cancellation/active_request_tracker.dart';
import 'package:dart_acdc/src/interceptors/cancellation_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

class FakeRequestInterceptorHandler extends RequestInterceptorHandler {
  RequestOptions? nextOptions;

  @override
  void next(RequestOptions requestOptions) {
    nextOptions = requestOptions;
  }

  @override
  void resolve(Response<dynamic> response, [bool newRequest = false]) {}

  @override
  void reject(DioException error, [bool newRequest = false]) {}
}

class FakeResponseInterceptorHandler extends ResponseInterceptorHandler {
  Response<dynamic>? nextResponse;

  @override
  void next(Response<dynamic> response) {
    nextResponse = response;
  }

  @override
  void resolve(Response<dynamic> response) {}

  @override
  void reject(DioException error, [bool newRequest = false]) {}
}

class FakeErrorInterceptorHandler extends ErrorInterceptorHandler {
  DioException? nextError;

  @override
  void next(DioException error) {
    nextError = error;
  }

  @override
  void resolve(Response<dynamic> response) {}

  @override
  void reject(DioException error, [bool newRequest = false]) {}
}

void main() {
  group('CancellationInterceptor', () {
    late CancellationInterceptor interceptor;
    late ActiveRequestTracker tracker;
    late RequestOptions requestOptions;

    setUp(() {
      tracker = ActiveRequestTracker();
      interceptor = CancellationInterceptor(tracker);
      requestOptions = RequestOptions(path: '/test');
    });

    group('onRequest', () {
      test('should add existing cancel token to tracker', () {
        final token = CancelToken();
        requestOptions.cancelToken = token;
        final handler = FakeRequestInterceptorHandler();

        interceptor.onRequest(requestOptions, handler);

        expect(tracker.isTracked(token), isTrue);
        expect(handler.nextOptions, requestOptions);
      });

      test('should create and add cancel token if missing', () {
        requestOptions.cancelToken = null;
        final handler = FakeRequestInterceptorHandler();

        interceptor.onRequest(requestOptions, handler);

        expect(requestOptions.cancelToken, isNotNull);
        expect(tracker.isTracked(requestOptions.cancelToken!), isTrue);
        expect(handler.nextOptions, requestOptions);
      });
    });

    group('onResponse', () {
      test('should remove token from tracker', () {
        final token = CancelToken();
        requestOptions.cancelToken = token;
        tracker.add(token); // Add manually to simulate request start

        final response = Response<dynamic>(requestOptions: requestOptions);
        final handler = FakeResponseInterceptorHandler();

        interceptor.onResponse(response, handler);

        expect(tracker.isTracked(token), isFalse);
        expect(handler.nextResponse, response);
      });
    });

    group('onError', () {
      test('should remove token from tracker', () {
        final token = CancelToken();
        requestOptions.cancelToken = token;
        tracker.add(token); // Add manually to simulate request start

        final error = DioException(requestOptions: requestOptions);
        final handler = FakeErrorInterceptorHandler();

        interceptor.onError(error, handler);

        expect(tracker.isTracked(token), isFalse);
        expect(handler.nextError, error);
      });
    });
  });
}
