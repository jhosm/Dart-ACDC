import 'package:dart_acdc/src/logging/log_level.dart';

/// Custom logger function type.
///
/// Accepts a log message, level, and optional metadata for structured logging.
///
/// Example:
/// ```dart
/// void myLogger(String message, LogLevel level, Map<String, dynamic>? metadata) {
///   print('[$level] $message');
///   if (metadata != null) {
///     print('  Metadata: $metadata');
///   }
/// }
/// ```
typedef AcdcLogger = void Function(
  String message,
  LogLevel level,
  Map<String, dynamic>? metadata,
);
