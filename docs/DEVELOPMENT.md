# Development Guide

## Prerequisites
- Flutter stable and Dart versions compatible with project constraints.
- Android Studio and Android SDK.
- JDK 17 for the current Android Gradle Plugin configuration.
- Two physical Android devices for media/projection testing.
- Backend runtime and PostgreSQL for integrated environments.

## Setup
1. Install Flutter and Android Studio.
2. Configure Flutter to use JDK 17 if multiple JDKs are installed: `flutter config --jdk-dir=<JDK-17-path>`.
3. Run `flutter doctor -v`.
4. Enter `apps/mobile` and run `flutter pub get`.
5. Connect a physical device and run `flutter devices`.
6. Run `flutter analyze` and `flutter test`.
7. Run `flutter build apk --debug` or `flutter run -d <device-id>`.

## Quality gates
Dart formatting/static analysis; Flutter tests; Android debug APK compilation; Kotlin compilation/Android lint; backend typecheck/build; PostgreSQL migration tests; secret/dependency scanning; real-device smoke tests for calling, projection and revocation.

A successful debug build is not proof that calling, screen sharing or remote interaction works. Record real-device acceptance separately.
