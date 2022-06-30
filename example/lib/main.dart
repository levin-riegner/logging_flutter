import 'dart:async';
import 'dart:developer';
import 'dart:ffi';
import 'package:flutter/foundation.dart';
import 'package:logging_flutter/logging_flutter.dart';

import 'package:flutter/material.dart';

class SampleClass {
  final String name;
  final int id;

  SampleClass({this.name, this.id});

  static void printSomeLogs() {
    Flogger.d("Debug message");

    Flogger.i("Info message");
    Flogger.i("Info message with object - ${SampleClass(name: "John", id: 1)}");

    Flogger.w("Warning message");
    try {
      throw Exception("Something bad happened");
    } catch (e) {
      Flogger.w("Warning message with exception $e");
    }

    Flogger.e("Error message with exception - ${Exception("Test Error")}");

    Flogger.i("Info message with a different logger name", loggerName: "Dio");

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
  });
}

void init() {
  // Init
  Flogger.init(config: FloggerConfig());
  if(kDebugMode) {
    // Send logs to Run console
    Flogger.registerListener(
      (record) => log(record.message, stackTrace: record.stackTrace),
    );
  }
  // Send logs to App Console
  Flogger.registerListener(
    (record) => LogConsole.add(OutputEvent(record.level, [record.message])),
  );
  // You can also use "registerListener" to log to Crashlytics or any other services
  if(kReleaseMode) {
    Flogger.registerListener((record) { 
      // Filter logs that may contain sensitive data
      if(record.loggerName != "App") return false;
      if(record.message.contains("apiKey")) return false;
      if(record.message.contains("password")) return false;
      // Send logs to logging services
      // FirebaseCrashlytics.instance.log(record.message);
      // DatadogSdk.instance.logs?.info(record.message);
    });
  }
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
          Center(
            child: TextButton(
                onPressed: () => LogConsole.open(context),
                child: Text("or click here to open Logs Console")),
          ),
        ],
      ),
    );
  }
}
