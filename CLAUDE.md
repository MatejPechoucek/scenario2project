# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run on default connected device
flutter run -d windows   # Run on Windows desktop
flutter run -d macos     # Run on macOS desktop
flutter run -d android   # Run on Android emulator/device
flutter run -d ios       # Run on iOS simulator/device (macOS only)
flutter test             # Run all tests
flutter test test/widget_test.dart  # Run a single test file
flutter analyze          # Lint (uses flutter_lints)
```

**Hot reload while running:** Press `r` in the terminal to hot reload, `R` to hot restart. In VS Code, add `"dart.flutterHotReloadOnSave": "always"` to settings for auto hot reload on save.

## Architecture

This is a minimal Flutter app. All application code lives in `lib/main.dart`, which contains:
- `MyApp` — root `MaterialApp` with Material 3 theme seeded from `Colors.deepPurple`
- `HomePage` — single stateless screen with a centered column layout

Tests are in `test/widget_test.dart` and use `flutter_test` to pump `MyApp` and assert on widget presence.

## Branch Workflow

Do **not** commit directly to `master`. Create a branch per feature:
```bash
git checkout -b your-name/feature-description
```
