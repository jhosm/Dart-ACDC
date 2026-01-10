import 'package:dart_acdc/src/cancellation/active_request_tracker.dart';
import 'package:dio/dio.dart';

/// Interceptor that manages request cancellation tokens.
///
/// Ensures every request has a [CancelToken] and registers it with the
/// [ActiveRequestTracker]. This enables collective cancellation of all
/// in-flight requests.
class CancellationInterceptor extends Interceptor {
  final ActiveRequestTracker _tracker;

  const CancellationInterceptor(this._tracker);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Ensure a CancelToken exists
    if (options.cancelToken == null) {
      options.cancelToken = CancelToken();
    }

    // Track the token
    _tracker.add(options.cancelToken!);

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _removeFromTracker(response.requestOptions);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _removeFromTracker(err.requestOptions);
    handler.next(err);
  }

  void _removeFromTracker(RequestOptions options) {
    if (options.cancelToken != null) {
      _tracker.remove(options.cancelToken!);
    }
  }
}
