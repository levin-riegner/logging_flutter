import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:logging_flutter/flogger.dart';
import 'package:logging_flutter/logging_flutter.dart';

void main() {
  init();
  runApp(MyApp());
}

void init() {
  // Show Debug Logs
  Flogger.showDebugLogs(true);
  // Send logs to Run console
  Flogger.registerListener((record) => log(record.message));
  // Can also use "registerListener" to log to Crashlytics or other services
  // Send logs to App Console
  Flogger.registerListener((record) => LogConsole.add(
      OutputEvent(record.level, [record.message])));
}

void printSomeLogs() {
  Flogger.d("Log message with 2 methods");

  Flogger.i("Info message");

  Flogger.w("Just a warning!");

  Flogger.e("Error! Something bad happened", object: Exception("Test Error"));
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
              child: Text("Shake Phone to open Console."),
            ),
          ),
          TextButton(
              onPressed: () => printSomeLogs(),
              child: Text("Print some Logs")),
          TextButton(
              onPressed: () => LogConsole.open(context),
              child: Text("or click here to open Console")),
        ],
      ),
    );
  }
}
