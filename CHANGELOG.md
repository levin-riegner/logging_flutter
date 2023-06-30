# Changelog

All notable changes to this project will be documented in this file.

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
