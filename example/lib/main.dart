import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:logging_flutter/flogger.dart';
import 'package:logging_flutter/logging_flutter.dart';

class SampleClass {
  final String name;
  final int id;

  SampleClass({this.name, this.id});

  static void printSomeLogs() {
    Flogger.d("Debug log message");

    Flogger.i("Info message");
    Flogger.i("Info message with object - ${SampleClass(name: "John", id: 1)}");

    Flogger.w("A warning message");
    try {
      throw Exception("Something bad happened");
    } catch (e) {
      Flogger.w("Warning with exception $e");
    }

    Flogger.e("Error with exception - ${Exception("Test Error")}");

    Flogger.i("Record with a different tag", tag: "Dio");

    // throw Exception("This has been thrown");
  }
}

void main() {
  runZonedGuarded(() {
    runApp(MyApp());
    init();
  }, (error, stack) {
    // Catch and log crashes
    Flogger.e('Unhandled error - $error', stackTrace: stack);
    Flogger.e("Stack trace: ${stack.toString().replaceAll("\n", " ")}");
  });
}

void init() {
  // Init
  Flogger.init(FloggerConfig(
    mightContainSensitiveData: (record) =>
        record.loggerName != FloggerConfig.defaultLoggerName,
  ));
  // Send logs to Run console
  Flogger.registerListener(
      (record) => log(record.message, stackTrace: record.stackTrace));
  // Send logs to App Console
  Flogger.registerListener(
    (record) => LogConsole.add(OutputEvent(record.level, [record.message])),
  );
  // You can also use "registerListener" to log to Crashlytics or any other services

  SampleClass.printSomeLogs();
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      routes: <String, WidgetBuilder>{
        "home": (context) => HomeWidget(),
      },
      initialRoute: "home",
      theme: ThemeData.dark(),
    );
  }
}

class HomeWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LogConsoleOnShake(
            dark: true,
            child: Center(
              child: Text("Shake Phone to open Logs Console."),
            ),
          ),
          TextButton(
              onPressed: () => SampleClass.printSomeLogs(),
              child: Text("Print some Logs")),
          TextButton(
              onPressed: () async {
                await Future.delayed(Duration(milliseconds: 300));
                throw Exception("An exception has been thrown");
              },
              child: Text("Throw Exception")),
          SizedBox(height: 16),
          TextButton(
              onPressed: () => LogConsole.open(context),
              child: Text("or click here to open Logs Console")),
        ],
      ),
    );
  }
}
