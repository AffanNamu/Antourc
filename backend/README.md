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

## Assistance consent API

- `POST /v1/calls/:callId/assistance-sessions` — the participant who is sharing their screen becomes the host.
- `GET /v1/assistance-sessions/:sessionId` — either participant can inspect the session.
- `POST /v1/assistance-sessions/:sessionId/control-requests` — helper requests only the explicitly listed gesture capabilities.
- `POST /v1/control-requests/:requestId/approve` — host approves a pending request; the grant expires after five minutes.
- `POST /v1/control-requests/:requestId/revoke` — host revokes an active grant.
- `POST /v1/assistance-sessions/:sessionId/end` — host ends assistance and revokes outstanding grants.

These endpoints persist authorization state. They do not themselves inject touch events; the Android host must independently verify the active grant and local consent for every gesture before any command is executed.

## Production requirements still outstanding

Configure TLS termination, managed PostgreSQL backups, SMTP deliverability, LiveKit/TURN capacity, monitoring/alerting, abuse reporting, account recovery, push delivery for incoming calls, rate-limit persistence and independent security review before public launch. The internal client milestone uses incoming-call polling until push delivery is implemented.
