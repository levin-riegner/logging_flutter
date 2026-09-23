import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:logging_flutter/logging_flutter.dart';

void main() {
  group("Flogger", () {
    setUp(Flogger.init);
    tearDown(() {
      Flogger.clearListeners();
    });
    test("captures logs emited with Flogger", () {
      final message = "Test message";
      Flogger.registerListener((record) {
        expect(record.message, message);
        expect(record.level, Level.INFO);
      });
      Flogger.i(message);
    });
    test("captures logs emited outside of Flogger", () {
      final message = "Test message";
      final loggerName = "TestLogger";
      Flogger.registerListener((record) {
        expect(record.message, message);
        expect(record.loggerName, loggerName);
        expect(record.level, Level.WARNING);
      });
      Logger(loggerName).warning(message);
    });
    test("logs to multiple Logger instances", () async {
      final message = "Test message";
      final loggerName1 = "TestLogger1";
      final loggerName2 = "TestLogger2";
      List<FloggerRecord> logs = [];
      Flogger.registerListener((record) {
        logs.add(record);
      });
      Logger(loggerName1).info(message);
      Logger(loggerName2).warning(message);
      expect(logs.length, 2);
      expect(logs[0].message, message);
      expect(logs[0].loggerName, loggerName1);
      expect(logs[0].level, Level.INFO);
      expect(logs[1].message, message);
      expect(logs[1].loggerName, loggerName2);
      expect(logs[1].level, Level.WARNING);
    });
    test("supports multiple listeners", () {
      final message = "Test message";
      final loggerName = "TestLogger";
      var count = 0;
      Flogger.registerListener((record) {
        expect(record.message, message);
        expect(record.loggerName, loggerName);
        expect(record.level, Level.SEVERE);
        count++;
      });
      Flogger.registerListener((record) {
        expect(record.message, message);
        expect(record.loggerName, loggerName);
        expect(record.level, Level.SEVERE);
        count++;
      });
      Logger(loggerName).severe(message);
      expect(count, 2);
    });
    test("clears all listeners", () {
      Flogger.registerListener((record) {
        fail("Should not be called");
      });
      Flogger.clearListeners();
      Flogger.i("message");
    });
    test("uses custom printer when provided", () {
      final printer = (record) {
        return "Custom printer: ${record.message}";
      };
      Flogger.init(config: FloggerConfig(printer: printer));
      Flogger.registerListener((record) {
        expect(record.printable(), "Custom printer: message");
      });
      Flogger.i("message");
    });
    test("uses FloggerConfig when printer is not provided", () {
      final loggerName = "TestLogger";
      Flogger.init(
        config: FloggerConfig(
          loggerName: loggerName,
          printClassName: false,
          printMethodName: false,
          showDateTime: false,
          showDebugLogs: true,
        ),
      );
      Flogger.registerListener((record) {
        print(record.printable());
        expect(record.printable(), "I/$loggerName: message");
      });
      Flogger.i("message");
    });

    test("maps convenience methods to levels and retains record fields", () {
      final records = <FloggerRecord>[];
      final trace = StackTrace.current;
      Flogger.registerListener(records.add);

      Flogger.d("debug");
      Flogger.i("info", loggerName: "Network");
      Flogger.w("warning");
      Flogger.e("error", stackTrace: trace);

      expect(records.map((record) => record.level), [
        Level.CONFIG,
        Level.INFO,
        Level.WARNING,
        Level.SEVERE,
      ]);
      expect(records.map((record) => record.message), [
        "debug",
        "info",
        "warning",
        "error",
      ]);
      expect(records[1].loggerName, "Network");
      expect(records.last.stackTrace, same(trace));
      expect(records.last.logRecord.stackTrace, same(trace));
      expect(records.last.time, isNotNull);
    });

    test("formats levels and a custom logger without caller names", () {
      Flogger.init(
        config: const FloggerConfig(
          printClassName: false,
          printMethodName: false,
        ),
      );
      final printed = <String>[];
      Flogger.registerListener((record) => printed.add(record.printable()));

      Flogger.d("debug");
      Flogger.i("info", loggerName: "Network");
      Flogger.w("warning");
      Flogger.e("error");

      expect(printed, [
        "D/App: debug",
        "I/Network: info",
        "W/App: warning",
        "E/App: error",
      ]);
    });

    test("showDebugLogs false filters debug records", () {
      Flogger.init(config: const FloggerConfig(showDebugLogs: false));
      final records = <FloggerRecord>[];
      Flogger.registerListener(records.add);

      Flogger.d("debug");
      Flogger.i("info");
      Logger("External").config("external debug");
      Logger("External").warning("external warning");

      expect(records.map((record) => record.message), [
        "info",
        "external warning",
      ]);
    });
  });
}
