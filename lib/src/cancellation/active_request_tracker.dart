import 'package:dio/dio.dart';

/// Tracks active HTTP requests to enable collective cancellation.
///
/// This class is thread-safe (in the context of Dart isolates) and maintains
/// a set of active [CancelToken]s.
class ActiveRequestTracker {
  final Set<CancelToken> _activeTokens = {};

  /// Adds a token to the tracker.
  void add(CancelToken token) {
    _activeTokens.add(token);
  }

  /// Removes a token from the tracker.
  void remove(CancelToken token) {
    _activeTokens.remove(token);
  }

  /// Cancels all active requests with the given [reason].
  ///
  /// After cancellation, the tracker is cleared.
  void cancelAll([Object? reason]) {
    // Create a copy to iterate while modifying might happen (though strictly synchronous here)
    final tokens = List<CancelToken>.from(_activeTokens);

    for (final token in tokens) {
      if (!token.isCancelled) {
        token.cancel(reason);
      }
    }

    _activeTokens.clear();
  }

  /// Checks if a token is currently tracked.
  bool isTracked(CancelToken token) => _activeTokens.contains(token);

  /// Returns the number of active requests.
  int get activeCount => _activeTokens.length;
}
