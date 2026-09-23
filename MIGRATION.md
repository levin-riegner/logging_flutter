# Migrating from 3.x to 4.0

## Requirements

Version 4.0 requires Dart 3.12 and Flutter 3.47 or newer. Android and iOS remain the declared platforms. Apps on older SDKs should stay on `^3.0.0` until their Flutter upgrade is complete.

## Logging calls and records

Existing `Flogger.init`, `d`, `i`, `w`, and `e` calls continue to compile. `FloggerRecord.message` remains the unformatted message; call `record.printable()` for the configured display string. Record fields such as `level`, `loggerName`, `stackTrace`, `className`, and `methodName` remain available.

`Flogger.init` still sets `Logger.root.level` according to `showDebugLogs`. This affects records emitted by other packages that use Dart's `logging` package. If you rely on another root level, configure the root logger after calling `Flogger.init` and test the resulting filter behavior.

## Listener ownership

`Flogger.registerListener` now returns a `FloggerListenerRegistration`. Keep it when a component needs to stop receiving records independently:

```dart
final registration = Flogger.registerListener((record) {
  // Forward the record to your destination.
});

await registration.cancel();
```

Existing call sites may ignore the return value. `Flogger.clearListeners()` now cancels all registrations owned by `Flogger` while preserving listeners attached directly to `Logger.root.onRecord`. Review code that previously used it to clear every root listener; those external subscriptions must be cancelled by their owners.

## In-app console

`LogConsole.add` still accepts an `OutputEvent` and an optional `bufferSize`. The capacity must be positive; `null` uses 1000. The open console now shows newly added events. Copy uses the current text and level filters, includes offscreen entries, and preserves each entry's original case. Call `LogConsole.clear()` to remove buffered entries, including from an open console.

The console UI now uses only Flutter core widgets. `LogConsole.open` chooses light or dark mode from the system setting when `dark` is omitted. Apps with a theme that differs from the system should pass `dark` explicitly.
