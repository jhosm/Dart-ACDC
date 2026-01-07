import 'package:dart_acdc/dart_acdc.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Integrates dart_acdc logging with Talker.
class TalkerLogDelegate implements AcdcLogDelegate {
  final Talker talker;

  TalkerLogDelegate(this.talker);

  @override
  void log(String message, LogLevel level, Map<String, dynamic> metadata) {
    final talkerLevel = _mapLevel(level);

    talker.logTyped(
      AcdcTalkerLog(message, logLevel: talkerLevel, data: metadata),
    );
  }

  // Map Acdc LogLevel to Talker LogLevel
  // Note: We use fully qualified names or explicit checks to avoid collisions
  // if imports were conflicting, but here we map manually.
  talker_flutter.LogLevel _mapLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return talker_flutter.LogLevel.debug;
      case LogLevel.info:
        return talker_flutter.LogLevel.info;
      case LogLevel.warning:
        return talker_flutter.LogLevel.warning;
      case LogLevel.error:
        return talker_flutter.LogLevel.error;
      case LogLevel.none:
        return talker_flutter.LogLevel.verbose;
    }
  }
}

/// Custom Talker log for ACDC events
class AcdcTalkerLog extends TalkerLog {
  AcdcTalkerLog(String message, {super.data, super.logLevel}) : super(message);

  @override
  String get title => 'ACDC';

  @override
  AnsiPen get pen => AnsiPen()..cyan();
}
