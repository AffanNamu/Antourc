# System Architecture

## Core boundary
AssistLink separates the **media plane** from the **control plane**.

### Mobile client
Flutter owns navigation, product UI, state presentation and account/contact flows. Native capabilities are behind typed interfaces implemented in Kotlin.

### Android host engine
Kotlin owns MediaProjection consent/lifecycle, foreground-service lifecycle, display metrics/orientation and any future approved accessibility integration. Android remains authoritative for system permissions and protected surfaces.

### Media plane
LiveKit/WebRTC carries camera, microphone and host screen tracks. Use short-lived server-issued room credentials with minimum room/track grants. Never ship permanent API secrets in the mobile app.

### Control plane
An authenticated backend owns identity, contacts, call/session state, authorization, expiry and token issuance. An authenticated WebSocket or RTC data channel may carry commands, but every command is checked against server-issued claims and host-local consent state.

### Persistence
PostgreSQL stores accounts, device registrations, contacts, call/session metadata, grants/revocations and minimal security events. Redis may hold short-lived ephemeral state. Do not persist screen frames, screenshots, audio or video by default.

## Session lifecycle
`idle -> ringing -> connected -> screen_share_pending -> screen_sharing -> control_requested -> control_approved`. Any active state may transition to `revoked`, `ended` or `expired` where valid. Control approval is separate from screen-share approval. Reconnect never recreates a revoked grant.

## Service boundaries
- Identity: account authentication and device registration.
- Contacts: trusted invitations and blocking.
- Calling: incoming/outgoing call signaling.
- Sessions: create, approve, revoke, end and inspect.
- Media token issuer: short-lived scoped LiveKit credentials.
- Push delivery: incoming call notification without sensitive payload data.
- Observability: redacted metadata, latency and failure metrics.

## Network behavior
Use WebRTC ICE with STUN and TURN fallback. TURN credentials are short-lived. Support LTE/5G/Wi-Fi changes, handover, adaptive quality and bounded reconnection. Media-room membership does not imply control authorization.

## Flutter feature boundaries
Authentication, contacts, calling, media, screen_sharing, assistance_session and settings_privacy. Use repository interfaces and Riverpod; do not couple widgets directly to platform channels.
