# Development Guide

## Prerequisites
- Flutter stable and Dart versions compatible with project constraints.
- Android Studio and Android SDK.
- JDK required by the selected Android Gradle Plugin.
- Two physical Android devices for media/projection testing.
- Backend runtime and PostgreSQL for integrated environments.

## Setup
1. Install Flutter and Android Studio.
2. Run `flutter doctor -v`.
3. Enter `apps/mobile` and run `flutter pub get`.
4. Connect a physical device and run `flutter devices`.
5. Run `flutter analyze` and `flutter test`.
6. Run `flutter run -d <device-id>`.

## Quality gates
Dart formatting/static analysis; Flutter tests; Kotlin compilation/Android lint; backend lint/typecheck/tests; secret/dependency scanning; real-device smoke tests for calling, projection and revocation.

A successful debug build is not proof that calling, screen sharing or remote interaction works. Record real-device acceptance separately.
