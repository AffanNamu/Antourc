import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { db } from './db.js';

const uuidSchema = z.string().uuid();
const controlRequestSchema = z.object({
  capabilities: z.array(z.enum(['tap', 'swipe', 'global_navigation'])).min(1).max(3).default(['tap', 'swipe']),
});

async function getSession(sessionId: string, userId: string) {
  const result = await db.query(
    `SELECT id, call_id, host_id, helper_id, status, created_at
     FROM assistance_sessions
     WHERE id = $1 AND (host_id = $2 OR helper_id = $2)`,
    [sessionId, userId],
  );
  return result.rows[0] as {
    id: string;
    call_id: string;
    host_id: string;
    helper_id: string;
    status: string;
    created_at: Date;
  } | undefined;
}

export async function registerAssistanceRoutes(app: FastifyInstance): Promise<void> {
  app.post('/v1/calls/:callId/assistance-sessions', { preHandler: [app.authenticate] }, async (request, reply) => {
    const callId = uuidSchema.safeParse((request.params as { callId?: string }).callId);
    if (!callId.success) return reply.code(400).send({ error: 'invalid_call_id' });
    const callResult = await db.query(
      `SELECT id, caller_id, callee_id FROM calls
       WHERE id = $1 AND status = 'accepted'
         AND (caller_id = $2 OR callee_id = $2)`,
      [callId.data, request.user.sub],
    );
    const call = callResult.rows[0];
    if (!call) return reply.code(404).send({ error: 'active_call_not_found' });
    const helperId = call.caller_id === request.user.sub ? call.callee_id : call.caller_id;
    const result = await db.query(
      `INSERT INTO assistance_sessions(call_id, host_id, helper_id, status)
       VALUES ($1, $2, $3, 'active')
       RETURNING id, call_id, host_id, helper_id, status, created_at`,
      [callId.data, request.user.sub, helperId],
    );
    return reply.code(201).send({ session: result.rows[0] });
  });

  app.get('/v1/calls/:callId/assistance-sessions', { preHandler: [app.authenticate] }, async (request, reply) => {
    const callId = uuidSchema.safeParse((request.params as { callId?: string }).callId);
    if (!callId.success) return reply.code(400).send({ error: 'invalid_call_id' });
    const membership = await db.query(
      'SELECT id FROM calls WHERE id = $1 AND (caller_id = $2 OR callee_id = $2)',
      [callId.data, request.user.sub],
    );
    if (!membership.rowCount) return reply.code(404).send({ error: 'call_not_found' });
    const result = await db.query(
      `SELECT id, call_id, host_id, helper_id, status, created_at
       FROM assistance_sessions WHERE call_id = $1 AND status = 'active'
       ORDER BY created_at DESC LIMIT 1`,
      [callId.data],
    );
    const session = result.rows[0];
    if (!session) return reply.send({ session: null, controlRequests: [] });
    const requests = await db.query(
      `SELECT id, status, capabilities, created_at, expires_at, approved_at, revoked_at
       FROM control_requests WHERE session_id = $1 ORDER BY created_at DESC LIMIT 10`,
      [session.id],
    );
    return reply.send({ session, controlRequests: requests.rows });
  });

  app.get('/v1/assistance-sessions/:sessionId', { preHandler: [app.authenticate] }, async (request, reply) => {
    const sessionId = uuidSchema.safeParse((request.params as { sessionId?: string }).sessionId);
    if (!sessionId.success) return reply.code(400).send({ error: 'invalid_session_id' });
    const session = await getSession(sessionId.data, request.user.sub);
    if (!session) return reply.code(404).send({ error: 'session_not_found' });
    const requests = await db.query(
      `SELECT id, status, capabilities, created_at, expires_at, approved_at, revoked_at
       FROM control_requests WHERE session_id = $1 ORDER BY created_at DESC LIMIT 10`,
      [session.id],
    );
    return reply.send({ session, controlRequests: requests.rows });
  });

  app.post('/v1/assistance-sessions/:sessionId/control-requests', { preHandler: [app.authenticate] }, async (request, reply) => {
    const sessionId = uuidSchema.safeParse((request.params as { sessionId?: string }).sessionId);
    const parsed = controlRequestSchema.safeParse(request.body ?? {});
    if (!sessionId.success || !parsed.success) return reply.code(400).send({ error: 'invalid_request' });
    const session = await getSession(sessionId.data, request.user.sub);
    if (!session || session.status !== 'active') return reply.code(404).send({ error: 'active_session_not_found' });
    if (session.helper_id !== request.user.sub) return reply.code(403).send({ error: 'only_helper_can_request_control' });

    await db.query(
      `UPDATE control_requests SET status = 'expired'
       WHERE session_id = $1 AND status = 'pending' AND expires_at <= now()`,
      [session.id],
    );
    const result = await db.query(
      `INSERT INTO control_requests(session_id, status, capabilities, expires_at)
       VALUES ($1, 'pending', $2::jsonb, now() + interval '60 seconds')
       RETURNING id, status, capabilities, created_at, expires_at`,
      [session.id, JSON.stringify(parsed.data.capabilities)],
    );
    return reply.code(201).send({ controlRequest: result.rows[0] });
  });

  app.post('/v1/control-requests/:requestId/approve', { preHandler: [app.authenticate] }, async (request, reply) => {
    const requestId = uuidSchema.safeParse((request.params as { requestId?: string }).requestId);
    if (!requestId.success) return reply.code(400).send({ error: 'invalid_request_id' });
    const result = await db.query(
      `UPDATE control_requests cr
       SET status = 'approved', approved_at = now(), expires_at = now() + interval '5 minutes'
       FROM assistance_sessions s
       WHERE cr.id = $1 AND cr.session_id = s.id
         AND s.host_id = $2 AND s.status = 'active'
         AND cr.status = 'pending' AND cr.expires_at > now()
       RETURNING cr.id, cr.session_id, cr.status, cr.capabilities, cr.expires_at`,
      [requestId.data, request.user.sub],
    );
    if (!result.rowCount) return reply.code(404).send({ error: 'request_not_approvable' });
    return reply.send({ controlGrant: result.rows[0] });
  });

  app.post('/v1/control-requests/:requestId/reject', { preHandler: [app.authenticate] }, async (request, reply) => {
    const requestId = uuidSchema.safeParse((request.params as { requestId?: string }).requestId);
    if (!requestId.success) return reply.code(400).send({ error: 'invalid_request_id' });
    const result = await db.query(
      `UPDATE control_requests cr
       SET status = 'rejected'
       FROM assistance_sessions s
       WHERE cr.id = $1 AND cr.session_id = s.id
         AND s.host_id = $2 AND s.status = 'active'
         AND cr.status = 'pending' AND cr.expires_at > now()
       RETURNING cr.id, cr.session_id, cr.status`,
      [requestId.data, request.user.sub],
    );
    if (!result.rowCount) return reply.code(404).send({ error: 'request_not_rejectable' });
    return reply.send({ controlRequest: result.rows[0] });
  });

  app.post('/v1/control-requests/:requestId/revoke', { preHandler: [app.authenticate] }, async (request, reply) => {
    const requestId = uuidSchema.safeParse((request.params as { requestId?: string }).requestId);
    if (!requestId.success) return reply.code(400).send({ error: 'invalid_request_id' });
    const result = await db.query(
      `UPDATE control_requests cr
       SET status = 'revoked', revoked_at = now()
       FROM assistance_sessions s
       WHERE cr.id = $1 AND cr.session_id = s.id
         AND s.host_id = $2 AND s.status = 'active'
         AND cr.status = 'approved'
       RETURNING cr.id, cr.session_id, cr.status, cr.revoked_at`,
      [requestId.data, request.user.sub],
    );
    if (!result.rowCount) return reply.code(404).send({ error: 'active_grant_not_found' });
    return reply.send({ controlGrant: result.rows[0] });
  });

  app.post('/v1/assistance-sessions/:sessionId/end', { preHandler: [app.authenticate] }, async (request, reply) => {
    const sessionId = uuidSchema.safeParse((request.params as { sessionId?: string }).sessionId);
    if (!sessionId.success) return reply.code(400).send({ error: 'invalid_session_id' });
    const client = await db.connect();
    try {
      await client.query('BEGIN');
      const ended = await client.query(
        `UPDATE assistance_sessions SET status = 'ended', ended_at = now()
         WHERE id = $1 AND host_id = $2 AND status = 'active'
         RETURNING id, status, ended_at`,
        [sessionId.data, request.user.sub],
      );
      if (!ended.rowCount) {
        await client.query('ROLLBACK');
        return reply.code(404).send({ error: 'active_session_not_found' });
      }
      await client.query(
        `UPDATE control_requests SET status = 'revoked', revoked_at = now()
         WHERE session_id = $1 AND status IN ('pending', 'approved')`,
        [sessionId.data],
      );
      await client.query('COMMIT');
      return reply.send({ session: ended.rows[0], accessRevoked: true });
    } catch (error) {
      await client.query('ROLLBACK').catch(() => undefined);
      request.log.error({ err: error }, 'Could not end assistance session');
      return reply.code(500).send({ error: 'session_end_failed' });
    } finally {
      client.release();
    }
  });
}
