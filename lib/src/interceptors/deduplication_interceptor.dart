import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';

/// Interceptor that deduplicates identical simultaneous requests.
///
/// If multiple identical requests are made while one is still in progress,
/// subsequent requests will wait for the first request's response instead of
/// making a new network call.
///
/// Requests are considered identical if they have the same:
/// - Method
/// - URI
/// - Headers
/// - Data
///
/// CancelTokens are EXCLUDED from the key to allow individual cancellation logic.
class DeduplicationInterceptor extends Interceptor {
  /// Map of active requests keys to their futures.
  final _activeRequests = HashMap<String, _ActiveRequest>();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_shouldDeduplicate(options)) {
      handler.next(options);
      return;
    }

    final key = _getRequestKey(options);

    // If an identical request is already active, join it
    if (_activeRequests.containsKey(key)) {
      final activeRequest = _activeRequests[key]!;

      // Subscribe to the existing request's future
      _subscribeToActiveRequest(activeRequest, options, handler);
    } else {
      // Start a new active request
      final completer = Completer<Response<dynamic>>();
      // Ignore unhandled errors on the future to prevent uncaught exceptions
      // when no duplicate requests subscribe to it.
      completer.future.ignore();

      final activeRequest = _ActiveRequest(completer);
      _activeRequests[key] = activeRequest;

      // Proceed with the request
      handler.next(options);
    }
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final key = _getRequestKey(response.requestOptions);

    if (_activeRequests.containsKey(key)) {
      final activeRequest = _activeRequests.remove(key)!;
      activeRequest.completer.complete(response);
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final key = _getRequestKey(err.requestOptions);

    if (_activeRequests.containsKey(key)) {
      final activeRequest = _activeRequests.remove(key)!;
      activeRequest.completer.completeError(err);
    }

    handler.next(err);
  }

  bool _shouldDeduplicate(RequestOptions options) {
    // Only deduplicate GET/HEAD requests by default unless configured otherwise
    // As per spec scenario: Non-idempotent requests (POST/PUT/DELETE) are NOT deduplicated
    // But spec says "deduplicate simultaneous identical idempotent requests (GET, HEAD)"
    if (options.method != 'GET' && options.method != 'HEAD') {
      return false;
    }

    // Spec: Stream Requests are NOT deduplicated
    if (options.responseType == ResponseType.stream) {
      return false;
    }

    // Spec: Configuration - check for inline disable
    if (options.extra['deduplicate'] == false) {
      return false;
    }

    return true;
  }

  String _getRequestKey(RequestOptions options) {
    // Generate key based on Method + URI + Headers + Data
    // CancelToken is explicitly excluded

    // Sort headers to ensure consistent key
    final sortedHeaders = options.headers.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final headersStr =
        sortedHeaders.map((e) => '${e.key}:${e.value}').join(',');

    return '${options.method}:${options.uri}:$headersStr:${options.data}';
  }

  void _subscribeToActiveRequest(
    _ActiveRequest activeRequest,
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    // Handle secondary cancellation
    // If this specific duplicate request is cancelled, we should stop waiting
    // but NOT cancel the primary request (which is driving the network call)
    if (options.cancelToken != null) {
      options.cancelToken!.whenCancel.then((_) {
        // If the future hasn't completed yet, we just ignore it from now on
        // for this listener.
        // However, standard handler.resolve/reject logic applies.
        // If we want to simulate "cancellation error" for this secondary request:
        if (!activeRequest.completer.isCompleted) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.cancel,
              message: 'Request cancelled',
            ),
          );
        }
      });
    }

    activeRequest.completer.future.then((response) {
      // If request was already cancelled, handler.reject would have been called
      // so we check if handler is still active? Dio handlers don't expose isCompleted easily.
      // But if we rejected above, calling resolve now might throw or be ignored.
      // Safer to check cancellation status again if possible, or just try resolve.

      // Note: We must clone the response for the secondary request to have correct requestOptions
      // matching the secondary request, NOT the primary one.

      if (options.cancelToken?.isCancelled ?? false) {
        return;
      }

      final secondaryResponse = Response(
        requestOptions: options,
        data: response.data,
        headers: response.headers,
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
        isRedirect: response.isRedirect,
        redirects: response.redirects,
        extra: response.extra,
      );

      handler.resolve(secondaryResponse);
    }).catchError((Object e) {
      if (options.cancelToken?.isCancelled ?? false) {
        return;
      }

      if (e is DioException) {
        handler.reject(e);
      } else {
        handler.reject(
          DioException(
            requestOptions: options,
            error: e,
          ),
        );
      }
    });
  }
}

class _ActiveRequest {
  _ActiveRequest(this.completer);
  final Completer<Response<dynamic>> completer;
}
