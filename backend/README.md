# AssistLink Backend

Fastify/TypeScript API for verified accounts, refresh-token rotation, one-to-one call signaling and short-lived LiveKit room credentials.

## Local setup

1. Install Node.js 22 and PostgreSQL 16.
2. Copy `.env.example` to `.env`; generate two independent 32+ character secrets.
3. Configure SMTP and a LiveKit project URL/API key/API secret.
4. Start PostgreSQL using the root `docker compose up -d postgres`.
5. Run `npm install`.
6. Run `npm run db:migrate`.
7. Run `npm run dev`.

The API refuses registration until SMTP is configured because accounts must verify their email before login. LiveKit API secrets remain server-side only.

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

Every call endpoint requires a bearer access token. LiveKit room credentials are only issued to a verified participant after the call is accepted. Tokens expire after five minutes and are room-scoped.

## Production requirements still outstanding

Configure TLS termination, managed PostgreSQL backups, SMTP deliverability, LiveKit/TURN capacity, monitoring/alerting, abuse reporting, account recovery, and security review before public launch. Incoming-call push delivery and rate-limit persistence are not yet implemented; the client must poll the incoming-call endpoint for the current internal testing milestone.
