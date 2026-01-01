/// Log verbosity levels.
///
/// Controls the amount of logging output from the HTTP client.
enum LogLevel {
  /// Detailed debug information (verbose).
  ///
  /// Logs all requests, responses, headers, and bodies.
  /// Use only in development.
  debug,

  /// General informational messages.
  ///
  /// Logs request/response summaries without full details.
  info,

  /// Warning messages for potential issues.
  ///
  /// Logs slow requests, retries, and non-fatal errors.
  warning,

  /// Error messages only.
  ///
  /// Logs failed requests and exceptions.
  error,

  /// No logging.
  ///
  /// Disables all HTTP client logging.
  none,
}
