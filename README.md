# AssistLink

AssistLink is an Android-first, consent-based remote assistance application. Two people can make an internet video call, share a device screen with explicit Android consent, and request narrowly-scoped assistance where Android and device policy permit it.

> **Status:** foundation in progress. No calling, screen-sharing or remote-control feature should be described as production-ready until it has passed real-device tests.

## Goals

- One application for both participants; either can call or assist.
- One-to-one internet audio/video calling.
- Host-initiated screen sharing using Android's system consent flow.
- Distinct, explicit and revocable remote-assistance consent.
- Visible host-side session state and immediate stop.
- No covert capture, unattended access or security-boundary bypass.

## Planned stack

Flutter/Dart client; Kotlin Android integration; LiveKit/WebRTC media; authenticated backend and control signaling; PostgreSQL persistence.

## Repository

- `apps/mobile`: Flutter client.
- `backend`: API and service implementation.
- `docs`: product, architecture, security and Android implementation requirements.
- `.github/workflows`: CI.

See [Development Guide](docs/DEVELOPMENT.md).

## Safety and platform constraints

Remote interaction is a separately gated capability. Android AccessibilityService is not unrestricted privileged input injection and use is subject to Android limitations and Google Play policy. We will not misclassify the app as an accessibility tool. Protected system surfaces, lock screens, passwords/PINs, biometrics, banking/payment confirmations and permission prompts remain host-only. Public Play distribution is not assumed until policy eligibility is reviewed.
