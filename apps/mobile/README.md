# AssistLink Mobile

Flutter Android client with authenticated sign-in, email verification, one-to-one LiveKit calling, Android screen sharing and host-approved remote gesture flows.

## Configure the API

The mobile app intentionally contains no backend or LiveKit secrets. Build with the deployed API URL:

```bash
flutter build apk --release --dart-define=ASSISTLINK_API_BASE_URL=https://your-api.example.com
```

The backend also needs PostgreSQL, SMTP and a LiveKit project configured. See [backend setup](../../backend/README.md).

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter run
```

## Platform behavior

- Android minimum API: 26.
- Screen capture requires Android's MediaProjection consent prompt.
- Remote gestures require the user to read the in-app disclosure, manually enable AssistLink in Android Accessibility settings, and approve each helper request during a call.
- Only tap and swipe are implemented. The app blocks selected system/permission surfaces, password focus, lock screen and screen-off state, but cannot guarantee detection of every sensitive third-party UI.
- Calls currently use incoming-call polling; push notifications are not yet connected.

## Real-device verification required

CI compiles and tests source, but it cannot prove camera/audio routing, screen capture, OEM foreground-service behavior or remote gesture dispatch. Test with two physical Android phones on separate networks before calling this release-ready.

Package: `com.assistlink.app`.
