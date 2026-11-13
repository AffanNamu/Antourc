# AssistLink

AssistLink is an Android-first, consent-based remote assistance application. Two people can make an internet video call, share a device screen with Android's system consent, and request narrowly scoped remote taps/swipes.

> **Status:** active development. The repository now contains a Flutter client, authenticated Fastify/PostgreSQL backend, LiveKit room integration, Android MediaProjection setup and a consent-gated AccessibilityService gesture executor. It is **not yet production-ready**: CI and real-device acceptance are still in progress, the backend/LiveKit/SMTP services must be deployed and configured, and Play policy review is required before public distribution.

## Implemented foundations

- Email/password accounts with email verification and rotating refresh tokens.
- Authenticated one-to-one call signaling and short-lived, room-scoped LiveKit credentials.
- Flutter call UI with camera/microphone controls and participant video rendering.
- Android system screen-capture permission flow and foreground service integration.
- Assistance sessions with separate helper request, host approval, rejection and revocation.
- Android gesture executor restricted to approved tap/swipe commands, a specific helper identity, monotonic command sequence and expiring local grant.
- In-app AccessibilityService disclosure and affirmative acknowledgement.
- CI for Flutter analysis/tests, Android debug APK compilation, backend typecheck/build and repository documentation.

## Architecture

- `apps/mobile`: Flutter Android client and Kotlin platform integration.
- `backend`: Fastify API, PostgreSQL migrations, authentication, call and assistance authorization.
- `docs`: product, architecture, security and Android platform requirements.
- `.github/workflows`: CI.

## Important constraints

AssistLink does not use the AccessibilityService as a screen reader and does not retrieve window text. It listens to limited app/window and password-focus events to block selected system surfaces, and dispatches only host-approved taps/swipes. This cannot identify every sensitive screen. Android lock state, screen-off state, password focus and selected system/permission surfaces are blocked, but users should approve only trusted helpers.

Google Play distribution requires the Accessibility API declaration, prominent disclosure/affirmative consent and review. AssistLink must not set `isAccessibilityTool=true` because it is not a disability-support tool. It must never bypass Android security/privacy controls or automate actions autonomously.

## Local development

- Mobile: [apps/mobile/README.md](apps/mobile/README.md)
- Backend: [backend/README.md](backend/README.md)
- System design: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Security: [docs/SECURITY_MODEL.md](docs/SECURITY_MODEL.md)

No real-device or production deployment success is claimed until tested and verified.
