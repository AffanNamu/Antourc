# AssistLink Backend

Fastify/TypeScript API for verified accounts, refresh-token rotation, one-to-one call signaling, LiveKit credentials and host-approved assistance grants.

## Local setup

1. Install Node.js 22 and PostgreSQL 16.
2. Copy `.env.example` to `.env`; generate two independent 32+ character secrets.
3. Configure SMTP and a LiveKit project URL/API key/API secret.
4. Start PostgreSQL using the root `docker compose up -d postgres`.
5. Run `npm install`.
6. Run `npm run db:migrate`.
7. Run `npm run dev`.

Registration is disabled until SMTP is configured. Accounts must verify their email before login. LiveKit API secrets remain server-side only.

## Authentication

- Email/password registration with a six-digit email verification code.
- Verification code expires after 10 minutes and has a five-attempt limit.
- Passwords are bcrypt-hashed.
- Access tokens are short-lived; refresh tokens are random, hashed at rest and rotated on use.
- Logout revokes the supplied refresh token.

## Calling API

- `POST /v1/calls` with `{ "calleeEmail": "..." }`
- `GET /v1/calls/incoming`
- `POST /v1/calls/:callId/accept`
- `POST /v1/calls/:callId/reject`
- `GET /v1/calls/:callId`
- `POST /v1/calls/:callId/token`
- `POST /v1/calls/:callId/end`

Every call endpoint requires a bearer access token. LiveKit room credentials are issued only to a verified participant after the call is accepted. Tokens expire after five minutes and are room-scoped.

## Assistance and remote control

- `POST /v1/calls/:callId/assistance-sessions` — create host/helper session when the host starts screen sharing.
- `GET /v1/calls/:callId/assistance-sessions` — participants read active session and request state.
- `GET /v1/assistance-sessions/:sessionId` — inspect session.
- `POST /v1/assistance-sessions/:sessionId/control-requests` — helper requests tap/swipe.
- `POST /v1/control-requests/:requestId/approve` — host approves; grant expires after five minutes.
- `POST /v1/control-requests/:requestId/reject` — host rejects.
- `POST /v1/control-requests/:requestId/revoke` — host revokes.
- `POST /v1/assistance-sessions/:sessionId/end` — host ends and revokes outstanding requests.

The API records authorization state only. The Android host also requires a local, expiring consent grant and checks each incoming LiveKit gesture command before dispatch.

## Production requirements outstanding

Configure TLS termination, managed PostgreSQL backups, SMTP deliverability, LiveKit/TURN capacity, monitoring/alerting, abuse reporting, account recovery, incoming-call push delivery, persistent rate limiting and independent security review before public launch.
