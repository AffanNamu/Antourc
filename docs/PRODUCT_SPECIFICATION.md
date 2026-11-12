# Product Specification

## Product
AssistLink is an Android-first, consent-based remote assistance application combining one-to-one video calling, live screen sharing and optional remote interaction.

## Roles
There are no permanent controller/host roles. Either participant can initiate a call or offer screen sharing. The screen-sharing device is the **host**; the viewer is the **helper**. Roles are session-scoped.

## V1 scope
- Account identity and device registration.
- Trusted contacts and invitation workflow.
- One-to-one incoming/outgoing audio/video calls.
- Call lifecycle, mute, camera toggle, camera switch and hang-up.
- Host-initiated screen sharing through Android's system consent dialog.
- Remote screen viewer with display dimensions/orientation metadata.
- Assistance request/approval/rejection.
- Persistent visible host-side session state and immediate stop.
- Minimal security metadata; no default media recording.
- Network interruption and cleanup handling.

## Remote interaction gate
Remote gestures are a separately gated capability. A prototype may investigate Android AccessibilityService gesture APIs, but implementation and distribution are contingent on Android platform constraints, disclosure, affirmative consent, security review and Google Play policy eligibility. Never misclassify AccessibilityService as an accessibility tool unless the product genuinely qualifies.

Only a minimal, approved command set may be enabled: tap, swipe and supported global navigation actions. Host can revoke at any time. Passwords, PINs, biometrics, payment confirmations, lock screens, protected system surfaces and security-sensitive interfaces remain host-only.

## Out of scope
Group calls, remote administration, unattended access, file transfer, recording/transcription, protected UI interaction and iOS client.

## UX requirements
1. Host always sees a clear persistent indication while screen sharing/control is active.
2. Screen capture requires Android system-mediated consent.
3. Remote control requires distinct approval after screen sharing starts.
4. Host can stop control independently from screen sharing and end the call.
5. Helper sees host identity, connection state and device display metadata.
6. Reconnect never silently restores control.
7. Server and host enforce authorization; client UI is not a security boundary.

## Acceptance criteria
- Two physical Android devices on unrelated internet connections complete a call.
- Host approves OS screen-capture prompt and helper receives live frames.
- Host explicitly approves assistance; commands are rejected before approval.
- Revocation is enforced locally and server-side.
- Reconnection does not silently restore control.
- Protected surfaces remain protected.
- Resources are released after call end, projection stop and process interruption.
- CI and real-device regression checks pass.
