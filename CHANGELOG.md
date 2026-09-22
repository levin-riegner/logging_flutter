# Changelog

All notable changes to this project will be documented in this file.

## 4.0.0

### Breaking

- Require Dart 3.12 and Flutter 3.47 or newer.
- `Flogger.clearListeners()` now cancels only listeners registered through `Flogger`; it no longer clears unrelated listeners on `Logger.root`.
- `LogConsole.add` rejects non-positive `bufferSize` values. An explicit `null` uses the default capacity of 1000.

### Added and fixed

- `Flogger.registerListener` returns a registration that can be cancelled independently.
- Records without a discoverable logger stack frame retain their message and level, with null class and method names.
- `LogConsole` updates while open and exposes `clear()` to empty its buffer.
- Copy includes every filtered log entry with its original letter case, including offscreen entries.
- Truncated and malformed ANSI sequences no longer disappear or throw.
- Updated dependencies, CI checks, and the Android and iOS example projects.

See [MIGRATION.md](MIGRATION.md) for upgrade guidance.

## 3.0.0

> Note: This release has breaking changes.

### Added

- Capture logs from external packages.
- Use `FloggerPrinter` to print logs in your custom format.
- Updated dependencies.

### Breaking

- Use `record.printable()` to get the formatted log message. `record.message` now only contains the actual message passed to the logger.

## 2.0.1

### Added

- Updated documentation.

## 2.0.0

### Added

- The plugin is now open-source.

### Breaking

- Removed shake dependency.
- Refactored flogger class.

## 1.0.1

### Added

- Expose ShakeDetector.

### Changed

- Sensors library for Sensors Plus.

## 1.0.0

### Added

- Initial release.
