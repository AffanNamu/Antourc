# Security and Privacy Model

## Objectives
- Only authenticated participants establish calls.
- Only the host authorizes capture and remote assistance on their device.
- Consent is explicit, visible, session-scoped and revocable.
- No hidden capture, unattended control or silent reauthorization.
- Commands are authenticated, integrity-protected, bounded and replay-resistant.
- Sensitive operations remain local to the host.

## Trust boundaries
1. Flutter UI is not a security boundary.
2. Backend session state is authoritative for account/session eligibility.
3. Host Kotlin process independently checks local consent for every command.
4. Android system permission surfaces and protected UI remain under Android control.
5. LiveKit room membership does not grant remote-control privileges.

## Controls
- TLS for API/signaling; WebRTC media encryption in transit.
- Short-lived, audience/room/role-scoped tokens.
- Secure device token storage and refresh-token rotation.
- Per-session random ID and monotonically increasing command sequence.
- Server-side authorization on every state transition.
- Host-local authorization check on every gesture.
- Rate limits, payload limits and gesture bounds.
- Revocation invalidates server grants, closes control channel and clears local command queue.
- No control after expiry, host restart or reconnection without fresh consent.
- Redact tokens, payloads, personal text and screen contents from logs.
- Data minimization and defined retention for security metadata.

## Consent sequence
1. Host starts screen sharing and approves Android's system projection dialog.
2. Helper requests remote assistance.
3. Host sees helper identity and requested capability.
4. Host explicitly approves a scoped grant.
5. Host sees persistent status and immediate stop control.
6. Revocation is enforced locally and propagated to the backend.

## Prohibited behavior
No hidden capture, notification abuse, AccessibilityService policy evasion, lock-screen interaction, credential capture, PIN/password entry, banking/payment confirmation, permission-dialog bypass, rooting, exploits or persistence outside an approved session.

## Incident response
Provide account blocking, session termination, token revocation, abuse reporting, security event review and a vulnerability contact before public release.
