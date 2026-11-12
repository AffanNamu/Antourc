# Android Implementation Notes

## MediaProjection
- Request permission through Android system UI for every new projection session as required by the target SDK.
- Start the correctly declared media-projection foreground service only after user approval.
- Register projection-stop callbacks and clean up virtual display, surface, encoder and service resources.
- Handle rotation, display-size changes, process death, app backgrounding and OEM battery restrictions.
- Never restart projection silently or reuse revoked authorization.

## Foreground service
Declare only required foreground-service types and permissions for the selected target SDK. Start from user-visible flows and display a persistent notification with a stop action. Review against current Android SDK requirements at implementation time.

## Remote interaction investigation
AccessibilityService gesture dispatch is not general privileged input injection. It is not guaranteed on all apps, protected screens or OEM builds. Host must manually enable the service and explicitly consent for each session. Accept only authenticated, bounded commands under a currently active local grant. Do not set the accessibility-tool designation unless the product genuinely qualifies.

Before shipping: review Google Play Accessibility API eligibility; test OS/OEM compatibility; review disclosure and consent; complete threat modeling and security review; document fallback when gesture execution is unavailable.

## Platform bridge
Use a versioned MethodChannel/EventChannel contract. Keep platform DTOs explicit and validate every value at the Kotlin boundary. Do not accept arbitrary command strings from Dart.

## Device testing
Test API 26, 29, 31, 33, 34, 35 and current stable API; include Pixel/AOSP and multiple OEM devices. Emulators do not replace projection, audio routing or accessibility real-device tests.
