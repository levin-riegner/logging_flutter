import "package:logging/logging.dart";
import 'package:stack_trace/stack_trace.dart';

class FloggerConfig {

  final String loggerName;
  final bool printClassName;
  final bool printMethodName;
  final bool showDateTime;
  final bool showDebugLogs;

  const FloggerConfig({
    // The name of default the logger
    this.loggerName = "App",
    // Print the class name where the log was triggered
    this.printClassName = true,
    // Print the method name where the log was triggered
    this.printMethodName = false,
    // Print the date and time when the log occurred
    this.showDateTime = false,
    // Print logs with Debug severity
    this.showDebugLogs = true,
  });
}

abstract class Flogger {
  static FloggerConfig _config = FloggerConfig();
  static Logger _logger = Logger(_config.loggerName);
  static final Map<String, Logger> _children = {};

  Flogger._();

  static init({FloggerConfig config = const FloggerConfig()}) {
    _config = config;
    _logger = Logger(_config.loggerName);
    Logger.root.level = _config.showDebugLogs ? Level.ALL : Level.INFO;
  }

  // region Log methods
  static d(String message, {String? loggerName}) => _log(
        message,
        loggerName: loggerName,
        severity: Level.CONFIG,
      );

  static i(String message, {String? loggerName}) => _log(
        message,
        loggerName: loggerName,
        severity: Level.INFO,
      );

  static w(String message, {String? loggerName}) => _log(
        message,
        loggerName: loggerName,
        severity: Level.WARNING,
      );

  static e(String message, {StackTrace? stackTrace, String? loggerName}) => _log(
        message,
        loggerName: loggerName,
        severity: Level.SEVERE,
        stackTrace: stackTrace,
      );

  // Log message to Logger
  static _log(
    String message, {
    String? loggerName,
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
    logMessage += "${loggerName ?? _config.loggerName} ";
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
    if (loggerName == null) {
      // Main logger
      _logger.log(severity, logMessage, null, stackTrace);
    } else {
      // Additional loggers
      if (_children.containsKey(loggerName)) {
        _children[loggerName]!.log(severity, logMessage, null, stackTrace);
      } else {
        _children[loggerName] = Logger(loggerName)
          ..log(severity, logMessage, null, stackTrace);
      }
    }
  }

// endregion

  static registerListener(void onRecord(FloggerRecord record)) {
    Logger.root.onRecord
        .map((e) => FloggerRecord.fromLogger(
              e,
              showDateTime: _config.showDateTime,
            ))
        .listen(onRecord);
  }
}

class FloggerRecord {
  final String loggerName;
  final Level level;
  final String message;
  final StackTrace? stackTrace;

  FloggerRecord._(
    this.loggerName,
    this.message,
    this.level,
    this.stackTrace,
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
      record.loggerName,
      message,
      record.level,
      stackTrace,
    );
  }
}
