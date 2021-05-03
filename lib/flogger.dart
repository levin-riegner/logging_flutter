import 'package:logging/logging.dart';

abstract class Flogger {
  static const String _loggerName = "App";

  static Logger _logger = Logger(_loggerName);

  Flogger._();

  // region Log methods
  static d(String message, {Object? object}) => debug(message, object: object);

  static debug(String message, {Object? object}) {
    _log(message, severity: Level.CONFIG, object: object);
  }

  static i(String message, {Object? object}) => info(message, object: object);

  static info(String message, {Object? object}) {
    _log(message, severity: Level.INFO, object: object);
  }

  static w(String message, {Object? object}) =>
      warning(message, object: object);

  static warning(String message, {Object? object}) {
    _log(message, severity: Level.WARNING, object: object);
  }

  static e(String message, {Object? object, StackTrace? stackTrace}) =>
      error(message, object: object, stackTrace: stackTrace);

  static error(String message, {Object? object, StackTrace? stackTrace}) {
    _log(message,
        severity: Level.SEVERE, object: object, stackTrace: stackTrace);
  }

  static _log(String message,
      {Level severity = Level.CONFIG, Object? object, StackTrace? stackTrace}) {
    StackTrace? stack = stackTrace;
    if (stack == null && object is Error) stack = object.stackTrace;

    if (object != null) {
      _logger.log(severity, "$message - $object", null, stack);
    } else {
      _logger.log(severity, message, null, stack);
    }
  }

  // endregion

  static showDebugLogs(bool enable) {
    Logger.root.level = enable ? Level.ALL : Level.INFO;
  }

  static registerListener(void onRecord(FloggerRecord record)) {
    Logger.root.onRecord
        .map((e) => FloggerRecord.fromLogger(e, e.loggerName != _loggerName))
        .listen(onRecord);
  }
}

class FloggerRecord {
  final String message;
  final Level level;
  final bool mightContainSensitiveData;

  FloggerRecord._(this.message, this.level, this.mightContainSensitiveData);

  factory FloggerRecord.fromLogger(
      LogRecord record, bool mightContainSensitiveData) {
    var message =
        '${record.loggerName}: ${record.level.name}: ${record.message}';
    if (record.stackTrace != null) message += '${record.stackTrace}';
    return FloggerRecord._(message, record.level, mightContainSensitiveData);
  }
}
