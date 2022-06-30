# Logging Flutter

An extension of the [Logging](https://pub.dev/packages/logging) package for Flutter.

## Overview

This package provides a simple class for logging messages in your applications.

## Features

- Print logs to the console using a standard format.
- Send logs to 3rd party services (ie: Crashlytics, DataDog, etc.)
- Print class and method names where the log was triggered.
- View and share all logs from inside the app.

## Get Started

### Initializing

Use the [Flogger](lib/flogger.dart) static class to access all logging methods.

1. Initialize the logger.

    ```dart
    Flogger.init();
    ```

1. Register a listener to print logs to the developer console.

    ```dart
    if (kDebugMode){
        Flogger.registerListener(
            (record) => log(record.message, stackTrace: record.stackTrace),
        );
    }
    ```

### Logging messages

Log messages with their severity using the following methods:

```dart
Flogger.d("Debug message");
Flogger.i("Info message");
Flogger.w("Warning message");
Flogger.e("Error message", stackTrace: null);
```

These calls will result in the logs below when using the default configuration:

```console
[log] D/App SampleClass: Debug message
[log] I/App SampleClass: Info message
[log] W/App SampleClass: Warning message
[log] E/App SampleClass: Error message
```

### Advanced Usage

#### Configuration

Use the [FloggerConfig](lib/flogger.dart) class when initializing the Flogger to configure its usage:

```dart
Flogger.init(config: FloggerConfig(...));
FloggerConfig({
    // The name of the default logger
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
```

#### Viewing logs inside the app

Use the [LogConsole](lib/src/log_console.dart) class to view your logs inside the app.

1. Add logs to the console buffer by registering a new listener.

    ```dart
    Flogger.registerListener(
        (record) => LogConsole.add(OutputEvent(record.level, [record.message])),
    );
    ```

1. Open the logs console to view all recorded logs.

    ```dart
    LogConsole.open(context)
    ```

#### Multiple Loggers

Use the `loggerName` parameter when adding logs to print them as a different logger. This can be useful for differentiating calls made from the different layers in your app. For example:

```dart
    Flogger.i("Info message", loggerName: "Network");
    Flogger.w("Warning message", loggerName: "Database");
```

#### Logging to 3rd party services

Register additional listeners to send logs to different services, for example:

```dart
if (kReleaseMode) {
    Flogger.registerListener((record) {
        // Filter logs that may contain sensitive data
        if(record.loggerName != "App") return false;
        if(record.message.contains("apiKey")) return false;
        if(record.message.contains("password")) return false;
        // Log to 3rd party services
        FirebaseCrashlytics.instance.log(record.message);
        DatadogSdk.instance.logs?.info(record.message);
    });
}
```

## Contributing

Contributions are most welcome! Feel free to open a new issue or pull request to make this project better.

### Deployment

1. Run `manager clean` to prevent caching issues.
2. Run `manager build` to build the project.
3. Finally run `manager deploy` to deploy the project.

## Credits

- [Logging](https://github.com/dart-lang/logging) - Copyright (c) 2013 the Dart project authors [BSD 3-Clause](https://github.com/dart-lang/logging/blob/master/LICENSE) for providing the logging framework this library depends on.
- [Logger Flutter](https://github.com/leisim/logger_flutter) - Copyright (c) 2019 Simon Leier [MIT License](https://github.com/leisim/logger_flutter/blob/master/LICENSE) for creating the log console.

## License

This repo is covered under the [MIT License](LICENSE).
