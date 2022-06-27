import "package:logging/logging.dart";
import 'package:stack_trace/stack_trace.dart';

class FloggerConfig {
  static const defaultLoggerName = "App";

  final String loggerName;
  final bool printClassName;
  final bool printMethodName;
  final bool showDateTime;
  final bool showDebugLogs;
  final bool Function(LogRecord)? mightContainSensitiveData;

  const FloggerConfig({
    this.loggerName = defaultLoggerName,
    this.printClassName = true,
    this.printMethodName = false,
    this.showDateTime = false,
    this.showDebugLogs = true,
    this.mightContainSensitiveData,
  });
}

abstract class Flogger {
  static FloggerConfig _config = FloggerConfig();
  static Logger _logger = Logger(_config.loggerName);
  static final Map<String, Logger> _children = {};

  Flogger._();

  static init(FloggerConfig config) {
    _config = config;
    _logger = Logger(_config.loggerName);
    Logger.root.level = _config.showDebugLogs ? Level.ALL : Level.INFO;
  }

  // region Log methods
  static d(String message, {String? tag}) => _log(
        message,
        tag: tag,
        severity: Level.CONFIG,
      );

  static i(String message, {String? tag}) => _log(
        message,
        tag: tag,
        severity: Level.INFO,
      );

  static w(String message, {String? tag}) => _log(
        message,
        tag: tag,
        severity: Level.WARNING,
      );

  static e(String message, {StackTrace? stackTrace, String? tag}) => _log(
        message,
        tag: tag,
        severity: Level.SEVERE,
        stackTrace: stackTrace,
      );

  // Log message to Logger
  static _log(
    String message, {
    String? tag,
    required Level severity,
    StackTrace? stackTrace,
  }) {
    String? className;
    String? methodName;
    try {
      // This variable can be ClassName.MethodName or only a function name, when it doesn't belong to a class, e.g. main()
      var member = Trace.current().frames[2].member!;
      // If there is a . in the member name, it means the method belongs to a class. Thus we can split it.
      if (member.contains(".")) {
        className = member.split(".")[0];
      } else {
        className = "";
      }
      // If there is a . in the member name, it means the method belongs to a class. Thus we can split it.
      if (member.contains(".")) {
        methodName = member.split(".")[1];
      } else {
        methodName = member;
      }
    } catch (e) {}

    var logMessage = "";
    // Append logger name
    logMessage += "${tag ?? _config.loggerName} ";
    // Append Class name and Method name
    if (className != null && _config.printClassName) {
      if (methodName != null && _config.printMethodName) {
        logMessage += "$className#$methodName: $message";
      } else {
        logMessage += "$className: $message";
      }
    } else {
      logMessage += message;
    }
    // Log
    if (tag == null) {
      // Main logger
      _logger.log(severity, logMessage, null, stackTrace);
    } else {
      // Additional loggers
      if (_children.containsKey(tag)) {
        _children[tag]!.log(severity, logMessage, null, stackTrace);
      } else {
        _children[tag] = Logger(tag)
          ..log(severity, logMessage, null, stackTrace);
      }
    }
  }

// endregion

  static registerListener(void onRecord(FloggerRecord record)) {
    Logger.root.onRecord
        .map((e) => FloggerRecord.fromLogger(
              e,
              mightContainSensitiveData:
                  _config.mightContainSensitiveData?.call(e) ?? false,
              showDateTime: _config.showDateTime,
            ))
        .listen(onRecord);
  }
}

class FloggerRecord {
  final String message;
  final Level level;
  final StackTrace? stackTrace;
  final bool mightContainSensitiveData;

  FloggerRecord._(
    this.message,
    this.level,
    this.stackTrace,
    this.mightContainSensitiveData,
  );

  static String _levelShort(Level level) {
    if (level == Level.CONFIG) {
      return "D";
    } else if (level == Level.INFO) {
      return "I";
    } else if (level == Level.WARNING) {
      return "W";
    } else if (level == Level.SEVERE) {
      return "E";
    } else {
      return "?";
    }
  }

  factory FloggerRecord.fromLogger(
    LogRecord record, {
    required bool mightContainSensitiveData,
    required bool showDateTime,
  }) {
    // Get stacktrace from record stackTrace or record object
    StackTrace? stackTrace = record.stackTrace;
    if (record.stackTrace == null && record.object is Error)
      stackTrace = (record.object as Error).stackTrace;
    // Create message
    var message = "";
    // Maybe add DateTime
    if (showDateTime) message += "${record.time} ";
    // Add message
    message += "${_levelShort(record.level)}/${record.message}";
    // Maybe add object
    if (record.object != null) message += " - ${record.object}";
    // Build Flogger record
    return FloggerRecord._(
      message,
      record.level,
      stackTrace,
      mightContainSensitiveData,
    );
  }
}
