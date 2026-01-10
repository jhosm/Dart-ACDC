import 'package:dart_acdc/dart_acdc.dart';
import 'package:talker_flutter/talker_flutter.dart' as talker_pkg;

/// Integrates dart_acdc logging with Talker.
class TalkerLogDelegate implements AcdcLogDelegate {
  final talker_pkg.Talker talker;

  TalkerLogDelegate(this.talker);

  @override
  void log(String message, LogLevel level, Map<String, dynamic> metadata) {
    final talkerLevel = _mapLevel(level);

    talker.logCustom(
      AcdcTalkerLog(message, logLevel: talkerLevel, data: metadata),
    );
  }

  // Map Acdc LogLevel to Talker LogLevel
  talker_pkg.LogLevel _mapLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return talker_pkg.LogLevel.debug;
      case LogLevel.info:
        return talker_pkg.LogLevel.info;
      case LogLevel.warning:
        return talker_pkg.LogLevel.warning;
      case LogLevel.error:
        return talker_pkg.LogLevel.error;
      case LogLevel.none:
        return talker_pkg.LogLevel.verbose;
    }
  }
}

/// Custom Talker log for ACDC events
class AcdcTalkerLog extends talker_pkg.TalkerLog {
  final Map<String, dynamic>? data;

  AcdcTalkerLog(String super.message, {this.data, super.logLevel});

  @override
  String get title => 'ACDC';

  @override
  String? get message {
    if (data != null && data!.isNotEmpty) {
      return '${super.message ?? ''}\nData: $data';
    }
    return super.message;
  }

  @override
  talker_pkg.AnsiPen get pen => talker_pkg.AnsiPen()..cyan();
}
