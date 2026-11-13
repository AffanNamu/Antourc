CREATE TABLE IF NOT EXISTS assistance_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  call_id UUID NOT NULL REFERENCES calls(id) ON DELETE CASCADE,
  host_id UUID NOT NULL REFERENCES users(id),
  helper_id UUID NOT NULL REFERENCES users(id),
  status TEXT NOT NULL CHECK (status IN ('active', 'ended')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at TIMESTAMPTZ,
  CHECK (host_id <> helper_id)
);

CREATE INDEX IF NOT EXISTS assistance_sessions_host_idx
  ON assistance_sessions(host_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS assistance_sessions_helper_idx
  ON assistance_sessions(helper_id, status, created_at DESC);

CREATE TABLE IF NOT EXISTS control_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES assistance_sessions(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'rejected', 'revoked', 'expired')),
  capabilities JSONB NOT NULL DEFAULT '["tap", "swipe"]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL,
  approved_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS control_requests_session_idx
  ON control_requests(session_id, status, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS one_pending_control_request_per_session
  ON control_requests(session_id) WHERE status = 'pending';
