/// Manages exponential backoff state and timing for retry operations.
///
/// This class tracks backoff state including the current backoff duration
/// and the last attempt timestamp, providing methods to wait when needed,
/// reset the backoff, and increment the backoff duration exponentially.
///
/// **Usage**:
/// ```dart
/// final manager = BackoffManager();
///
/// try {
///   await manager.waitIfNeeded();
///   // Perform operation
///   manager.reset(); // Success - reset backoff
/// } on ServerException {
///   manager.increment(); // Failure - increase backoff
///   rethrow;
/// }
/// ```
class BackoffManager {
  int _backoffSeconds = 0;
  DateTime? _lastAttempt;
  bool _waitSatisfied = false;

  /// Waits if backoff is active and not enough time has elapsed.
  ///
  /// This method checks if a backoff period is active and if sufficient
  /// time has passed since the last attempt. If not, it delays execution
  /// to respect the backoff period.
  ///
  /// After this method completes, [shouldWait] will return false because
  /// the backoff requirement has been satisfied for this backoff period.
  Future<void> waitIfNeeded() async {
    // Check if we need to wait based on PREVIOUS attempt
    if (_backoffSeconds > 0 && _lastAttempt != null && !_waitSatisfied) {
      final timeSinceLastAttempt = DateTime.now().difference(_lastAttempt!);
      final backoffDuration = Duration(seconds: _backoffSeconds);

      if (timeSinceLastAttempt < backoffDuration) {
        await Future<void>.delayed(backoffDuration - timeSinceLastAttempt);
      }
    }

    // Record this attempt timestamp
    _lastAttempt = DateTime.now();
    // Mark that we've satisfied the wait requirement for this backoff period
    _waitSatisfied = true;
  }

  /// Resets the backoff to zero.
  ///
  /// Call this when an operation succeeds to clear any backoff state.
  void reset() {
    _backoffSeconds = 0;
    _waitSatisfied = false;
  }

  /// Increments the backoff duration exponentially.
  ///
  /// The backoff starts at 1 second and doubles with each increment,
  /// up to the specified [maxSeconds] (default: 30 seconds).
  ///
  /// Example progression: 1s → 2s → 4s → 8s → 16s → 30s (clamped)
  void increment({int maxSeconds = 30}) {
    _backoffSeconds =
        (_backoffSeconds == 0 ? 1 : _backoffSeconds * 2).clamp(0, maxSeconds);
    // New backoff period requires a new wait
    _waitSatisfied = false;
  }

  /// Returns true if a backoff delay is currently needed.
  ///
  /// This checks if the backoff period is active and if enough time
  /// has passed since the last attempt.
  bool shouldWait() {
    // If we've already satisfied the wait for this backoff period, no need to wait
    if (_waitSatisfied) return false;

    if (_backoffSeconds == 0 || _lastAttempt == null) return false;

    final timeSinceLastAttempt = DateTime.now().difference(_lastAttempt!);
    final backoffDuration = Duration(seconds: _backoffSeconds);

    return timeSinceLastAttempt < backoffDuration;
  }

  /// Returns the duration that should be waited.
  ///
  /// Returns [Duration.zero] if no wait is needed.
  Duration getWaitDuration() {
    // If we've already satisfied the wait for this backoff period, no wait needed
    if (_waitSatisfied) return Duration.zero;

    if (_backoffSeconds == 0 || _lastAttempt == null) return Duration.zero;

    final timeSinceLastAttempt = DateTime.now().difference(_lastAttempt!);
    final backoffDuration = Duration(seconds: _backoffSeconds);

    final remaining = backoffDuration - timeSinceLastAttempt;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Returns the current backoff duration in seconds.
  ///
  /// Useful for testing or monitoring backoff state.
  int get currentBackoffSeconds => _backoffSeconds;
}
