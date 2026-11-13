# Android Implementation Notes

## MediaProjection and LiveKit screen sharing

- The Flutter call session requests Android's system capture-consent dialog before screen publication.
- The screen-share foreground service is declared with the media-projection type and required permission.
- Screen capture is tied to an active call; stop-share and call-end paths clean up the LiveKit screen track and foreground execution.
- Validate projection stop callbacks, rotation, display-size changes, process death, backgrounding and OEM battery restrictions on physical devices.
- Never restart projection silently or reuse revoked authorization.

## Foreground service

Declare only required foreground-service types and permissions for the selected target SDK. Start from user-visible flows and show a persistent notification while screen capture is active. Review current Android requirements at release time.

## Remote gesture executor

The Kotlin AccessibilityService implementation:
- declares `canPerformGestures=true` and `canRetrieveWindowContent=false`;
- does not inspect view hierarchies or read on-screen text;
- listens only for app/window changes and password-focus events;
- blocks gestures while the keyguard is locked, screen is off, a password field is focused, or selected Android system/permission packages are foregrounded;
- accepts only `tap` and `swipe`, normalized coordinates, bounded swipe duration, matching session UUID, approved helper identity, unexpired local grant and strictly increasing command sequence;
- clears the local grant when the service is destroyed or the host revokes access.

This is a bounded assistance executor, not unrestricted privileged input injection. Android does not expose a universal reliable way to identify every sensitive screen without inspecting app content. Do not claim that all banking, payment, password or third-party secure screens can be detected. The host must approve only trusted helpers and retain an immediate stop/revoke path.

## Google Play policy gate

AssistLink is not a disability-support app and must not declare `isAccessibilityTool=true`. Before Play distribution:
- complete the Accessibility API declaration in Play Console;
- document the use in the Play listing;
- show the in-app prominent disclosure before the system settings flow;
- obtain affirmative user acknowledgement;
- verify the current policy interpretation for remote assistance;
- never use Accessibility API to bypass Android security/privacy controls or to autonomously initiate, plan or execute actions.

If policy approval is not available, remote gesture functionality must be disabled for the Play build or distributed only through a separately reviewed permitted channel.

## Platform bridge

A versioned MethodChannel connects Flutter to Kotlin. The native boundary validates session ID, sender identity, sequence, capability, expiry and coordinate bounds independently of Dart UI state.

## Device testing

Test API 26, 29, 31, 33, 34, 35 and current stable API; include Pixel/AOSP and multiple OEM devices. Emulators do not replace projection, audio routing or accessibility real-device acceptance.
