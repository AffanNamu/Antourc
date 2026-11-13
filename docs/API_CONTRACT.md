# API Contract

The endpoints below are implemented in the Fastify backend unless marked otherwise. All authenticated routes require a bearer access token.

## Authentication

- `POST /v1/auth/register` — register and send email verification code.
- `POST /v1/auth/verify-email` — verify six-digit email code.
- `POST /v1/auth/login` — issue short-lived access token and refresh token.
- `POST /v1/auth/refresh` — rotate refresh token.
- `POST /v1/auth/logout` — revoke supplied refresh token.
- `GET /v1/auth/me` — current verified account.

## Calls

- `POST /v1/calls` — create call with `{ "calleeEmail": "..." }`.
- `GET /v1/calls/incoming` — list pending incoming calls.
- `POST /v1/calls/{callId}/accept` — callee accepts.
- `POST /v1/calls/{callId}/reject` — callee rejects.
- `GET /v1/calls/{callId}` — participant reads call state.
- `POST /v1/calls/{callId}/token` — issue five-minute, room-scoped LiveKit token to an accepted participant.
- `POST /v1/calls/{callId}/end` — end call.

## Assistance and consent

- `POST /v1/calls/{callId}/assistance-sessions` — the participant who is sharing becomes host.
- `GET /v1/calls/{callId}/assistance-sessions` — either call participant reads the active assistance session and requests.
- `GET /v1/assistance-sessions/{sessionId}` — read session and control requests.
- `POST /v1/assistance-sessions/{sessionId}/control-requests` — helper requests the tap/swipe capabilities.
- `POST /v1/control-requests/{requestId}/approve` — host approves a pending request; grant expires after five minutes.
- `POST /v1/control-requests/{requestId}/reject` — host rejects a pending request.
- `POST /v1/control-requests/{requestId}/revoke` — host revokes an approved request.
- `POST /v1/assistance-sessions/{sessionId}/end` — host ends session and revokes outstanding requests.

## Authorization and execution

Only authenticated call participants can access their call/session. Only the helper can request control. Only the host can approve, reject, revoke or end the assistance session. The helper cannot grant themselves access.

Backend approval is necessary but not sufficient: the host app must also store a matching local grant after the host explicitly approves. Kotlin checks session UUID, helper identity, expiry, capability and monotonic sequence for each gesture. The LiveKit room token itself does not authorize remote gestures.

## Not implemented yet

Incoming-call push delivery, WebSocket signaling outside LiveKit, account recovery, production rate-limit storage and abuse reporting remain outstanding. Incoming calls are polled by the client.
