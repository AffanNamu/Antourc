CREATE UNIQUE INDEX IF NOT EXISTS one_active_assistance_session_per_call
  ON assistance_sessions(call_id)
  WHERE status = 'active';
