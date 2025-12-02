import 'package:talker_flutter/talker_flutter.dart';

class LoggerService {

  factory LoggerService() => _instance;
  LoggerService._internal();

  static final LoggerService _instance = LoggerService._internal();

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
      settings: TalkerSettings(
        
      ),
    );
  }

  static Talker get _logger => LoggerService().talker;

  static void debug(String message) {
    _logger.debug(message);
  }

  static void info(String message) {
    _logger.info(message);
  }

  static void warning(String message) {
    _logger.warning(message);
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.error(message, error, stackTrace);
  }

  static void db(String message) {
    _logger.logCustom(DatabaseLog(message));
  }
}

class DatabaseLog extends TalkerLog {
  DatabaseLog(super.message);

  @override
  String get title => 'DATABASE';
}
