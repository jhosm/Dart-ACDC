import 'package:dart_acdc/src/logging/log_level.dart';

/// Interface for custom logging implementations.
///
/// Implement this interface to bridge [LoggingInterceptor] logs to external
/// logging libraries like Talker, Logger, or Fimber.
///
/// Example:
/// ```dart
/// class MyLoggerDelegate implements AcdcLogDelegate {
///   @override
///   void log(String message, LogLevel level, Map<String, dynamic> metadata) {
///     print('[$level] $message');
///   }
/// }
/// ```
abstract interface class AcdcLogDelegate {
  /// Logs a message with the specified level and metadata.
  ///
  /// The [metadata] map contains structured information about the request/response,
  /// including redacted headers and body.
  void log(String message, LogLevel level, Map<String, dynamic> metadata);
}
