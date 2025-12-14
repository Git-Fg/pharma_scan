import 'package:riverpod/riverpod.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Provider for LoggerService - singleton instance managed by Riverpod
final loggerProvider = Provider<LoggerService>((ref) {
  final service = LoggerService();
  service.init();
  return service;
});

class LoggerService {
  LoggerService();

  Talker? _talker;

  Talker get talker {
    final currentTalker = _talker;
    if (currentTalker != null) {
      return currentTalker;
    }
    init();
    return _talker!;
  }

  void init() {
    if (_talker != null) {
      return;
    }

    _talker = TalkerFlutter.init(
      settings: TalkerSettings(),
    );
  }

  void debug(String message) {
    talker.debug(message);
  }

  void info(String message) {
    talker.info(message);
  }

  void warning(String message) {
    talker.warning(message);
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    talker.error(message, error, stackTrace);
  }

  void db(String message) {
    talker.logCustom(DatabaseLog(message));
  }
}

class DatabaseLog extends TalkerLog {
  DatabaseLog(super.message);

  @override
  String get title => 'DATABASE';
}
