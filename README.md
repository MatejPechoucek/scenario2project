# Scenario 2 Project

A Flutter mobile application template that runs on both **Android** and **iOS**.

## Prerequisites

Before you begin, make sure you have the following installed:

- **Flutter SDK** (3.x or later) — [Install Flutter](https://docs.flutter.dev/get-started/install)
- **Android Studio** — for Android emulator and SDK tools
- **Xcode** (macOS only) — for iOS simulator and builds
- **Git** — for version control

Verify your setup by running:

```
flutter doctor
```

Fix any issues reported before continuing.

## Getting Started

1. **Clone the repository**

   ```
   git clone <repo-url>
   cd scenario2project
   ```

2. **Install dependencies**

   ```
   flutter pub get
   ```

3. **Run the app**

   - To run on a connected device or emulator:

     ```
     flutter run
     ```

   - To run specifically on Android:

     ```
     flutter run -d android
     ```

   - To run specifically on iOS (macOS only):

     ```
     flutter run -d ios
     ```

4. **Run tests**

   ```
   flutter test
   ```

## For Team Members — Branch Workflow

> **Important:** Do **not** work directly on the `master` branch.

Before making any changes, create your own branch:

```
git checkout -b your-name/feature-description
```

For example:

```
git checkout -b alice/add-login-page
```

When your feature is ready, push your branch and open a pull request:

```
git push origin your-name/feature-description
```

This keeps `master` clean and makes it easy to review each other's work.

## Project Structure

```
lib/
  main.dart        — App entry point and home screen
test/
  widget_test.dart — Widget tests
android/           — Android platform files
ios/               — iOS platform files
```

## Useful Resources

- [Flutter documentation](https://docs.flutter.dev/)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter cookbook](https://docs.flutter.dev/cookbook)
