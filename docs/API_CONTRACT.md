# API Contract (Proposed)

This is a target contract, not evidence that endpoints are implemented.

## Session states
`created, ringing, connected, screen_share_pending, screen_sharing, control_requested, control_approved, revoked, ended, expired`.

## Proposed endpoints
- `POST /v1/calls` — create outgoing call.
- `POST /v1/calls/{id}/accept` — accept incoming call.
- `POST /v1/calls/{id}/reject` — reject incoming call.
- `POST /v1/sessions` — create assistance session for an active call.
- `POST /v1/sessions/{id}/screen-share` — record host-approved share start.
- `POST /v1/sessions/{id}/control-requests` — request assistance.
- `POST /v1/sessions/{id}/control-requests/{requestId}/approve` — host approval.
- `POST /v1/sessions/{id}/revoke` — revoke access.
- `POST /v1/sessions/{id}/end` — end session.
- `POST /v1/sessions/{id}/media-token` — issue short-lived scoped media credentials.

## Authorization
Every endpoint requires authenticated identity and checks participant membership. Only the host may approve/revoke host-side capture and control. A helper cannot approve their own request. Media tokens are short-lived and room/participant-scoped. Expired/revoked IDs cannot be reused. State changes use optimistic concurrency/version checks.

## Control message envelope
Include protocol version, session ID, sender identity, sequence, issued-at, expiry and typed payload. The host independently checks authorization and bounds. Never accept arbitrary shell commands, intents, reflection, text broadcasts or executable payloads.
