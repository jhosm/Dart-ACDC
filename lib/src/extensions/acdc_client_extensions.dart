import 'dart:async';
import 'package:dart_acdc/src/cancellation/active_request_tracker.dart';
import 'package:dart_acdc/src/interceptors/cache_interceptor.dart'
    show AcdcCacheInterceptor;
import 'package:dart_acdc/src/network_info/network_info.dart';
import 'package:dio/dio.dart';

/// Extensions for accessing [NetworkInfo] from a [Dio] client instance.
extension AcdcClientExtensions on Dio {
  /// Retrieves the [NetworkInfo] associated with this client.
  ///
  /// Returns `null` if the client was not configured with offline detection support
  /// (though `AcdcClientBuilder` adds it by default).
  NetworkInfo? get networkInfo =>
      options.extra['_acdc_network_info'] as NetworkInfo?;

  /// Closes the client and disposes associated resources including [NetworkInfo].
  ///
  /// This is a convenience method to properly clean up resources that [Dio.close]
  /// doesn't know about, such as the network monitoring stream.
  void closeAcdc({bool force = false}) {
    close(force: force);
    networkInfo?.dispose();
    activeRequestTracker?.cancelAll();
  }

  /// Cancels all active requests tracked by [ActiveRequestTracker].
  ///
  /// [reason]: Optional reason for cancellation.
  void cancelAll([Object? reason]) {
    activeRequestTracker?.cancelAll(reason);
  }

  /// Retrieves the [ActiveRequestTracker] associated with this client.
  ActiveRequestTracker? get activeRequestTracker =>
      options.extra['_acdc_active_request_tracker'] as ActiveRequestTracker?;

  /// Streams the response, emitting cached data immediately (if available via SWR)
  /// and then fresh data from the network.
  ///
  /// This requires [AcdcCacheInterceptor] to be configured with SWR enabled.
  /// If SWR is not active or not triggered, this stream behaves like a standard
  /// request, emitting a single response.
  Stream<Response<T>> streamRequest<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async* {
    Future<dynamic>? backgroundRefreshFuture;

    // Callback to capture background refresh future from AcdcCacheInterceptor
    void swrCallback(Future<dynamic> future) {
      backgroundRefreshFuture = future;
    }

    // Merge callback into options
    final requestOptions = (options ?? Options()).copyWith(
      extra: {
        if (options?.extra != null) ...options!.extra!,
        'swr_callback': swrCallback,
      },
    );

    // Make the initial request
    final initialResponse = await request<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: requestOptions,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    yield initialResponse;

    // If a background refresh was triggered, await and yield it
    if (backgroundRefreshFuture != null) {
      try {
        final freshResponse = await backgroundRefreshFuture;
        if (freshResponse is Response) {
          // Cast explicitly to T if possible, assuming response types match
          yield freshResponse as Response<T>;
        }
      } catch (e) {
        // Forward errors from background refresh
        rethrow;
      }
    }
  }
}
