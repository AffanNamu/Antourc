import { randomUUID } from 'node:crypto';
import { AccessToken } from 'livekit-server-sdk';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { db } from './db.js';
import { env } from './env.js';

const createCallSchema = z.object({ calleeEmail: z.string().email() });
const idSchema = z.string().uuid();

async function participantCall(callId: string, userId: string) {
  const result = await db.query(
    `SELECT id, caller_id, callee_id, room_name, status, created_at, accepted_at
     FROM calls WHERE id = $1 AND (caller_id = $2 OR callee_id = $2)`,
    [callId, userId],
  );
  return result.rows[0] as {
    id: string;
    caller_id: string;
    callee_id: string;
    room_name: string;
    status: string;
    created_at: Date;
    accepted_at: Date | null;
  } | undefined;
}

export async function registerCallRoutes(app: FastifyInstance): Promise<void> {
  app.get('/v1/calls/incoming', { preHandler: [app.authenticate] }, async (request, reply) => {
    await db.query(
      `UPDATE calls SET status = 'expired', ended_at = now()
       WHERE callee_id = $1 AND status = 'ringing' AND created_at < now() - interval '60 seconds'`,
      [request.user.sub],
    );
    const result = await db.query(
      `SELECT c.id, c.status, c.created_at, u.display_name AS caller_name
       FROM calls c JOIN users u ON u.id = c.caller_id
       WHERE c.callee_id = $1 AND c.status = 'ringing'
       ORDER BY c.created_at DESC LIMIT 20`,
      [request.user.sub],
    );
    return reply.send({ calls: result.rows });
  });

  app.post('/v1/calls', { preHandler: [app.authenticate] }, async (request, reply) => {
    const parsed = createCallSchema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'invalid_request' });
    const target = await db.query(
      'SELECT id FROM users WHERE email = $1 AND email_verified_at IS NOT NULL',
      [parsed.data.calleeEmail.trim().toLowerCase()],
    );
    const calleeId = target.rows[0]?.id as string | undefined;
    if (!calleeId) return reply.code(404).send({ error: 'contact_not_found' });
    if (calleeId === request.user.sub) return reply.code(400).send({ error: 'cannot_call_self' });

    const callId = randomUUID();
    const roomName = `assistlink_${callId.replaceAll('-', '')}`;
    const result = await db.query(
      `INSERT INTO calls(id, caller_id, callee_id, room_name, status)
       VALUES ($1, $2, $3, $4, 'ringing')
       RETURNING id, status, created_at`,
      [callId, request.user.sub, calleeId, roomName],
    );
    return reply.code(201).send({ call: result.rows[0] });
  });

  app.post('/v1/calls/:callId/accept', { preHandler: [app.authenticate] }, async (request, reply) => {
    const callId = idSchema.safeParse((request.params as { callId?: string }).callId);
    if (!callId.success) return reply.code(400).send({ error: 'invalid_call_id' });
    const result = await db.query(
      `UPDATE calls SET status = 'accepted', accepted_at = now()
       WHERE id = $1 AND callee_id = $2 AND status = 'ringing'
         AND created_at >= now() - interval '60 seconds'
       RETURNING id, status, accepted_at`,
      [callId.data, request.user.sub],
    );
    if (!result.rowCount) return reply.code(404).send({ error: 'call_not_available' });
    return reply.send({ call: result.rows[0] });
  });

  app.post('/v1/calls/:callId/reject', { preHandler: [app.authenticate] }, async (request, reply) => {
    const callId = idSchema.safeParse((request.params as { callId?: string }).callId);
    if (!callId.success) return reply.code(400).send({ error: 'invalid_call_id' });
    const result = await db.query(
      `UPDATE calls SET status = 'rejected', ended_at = now()
       WHERE id = $1 AND callee_id = $2 AND status = 'ringing' RETURNING id, status`,
      [callId.data, request.user.sub],
    );
    if (!result.rowCount) return reply.code(404).send({ error: 'call_not_available' });
    return reply.send({ call: result.rows[0] });
  });

  app.get('/v1/calls/:callId', { preHandler: [app.authenticate] }, async (request, reply) => {
    const callId = idSchema.safeParse((request.params as { callId?: string }).callId);
    if (!callId.success) return reply.code(400).send({ error: 'invalid_call_id' });
    const call = await participantCall(callId.data, request.user.sub);
    if (!call) return reply.code(404).send({ error: 'call_not_found' });
    return reply.send({
      call: {
        id: call.id,
        status: call.status,
        createdAt: call.created_at,
        acceptedAt: call.accepted_at,
      },
    });
  });

  app.post('/v1/calls/:callId/token', { preHandler: [app.authenticate] }, async (request, reply) => {
    const callId = idSchema.safeParse((request.params as { callId?: string }).callId);
    if (!callId.success) return reply.code(400).send({ error: 'invalid_call_id' });
    const call = await participantCall(callId.data, request.user.sub);
    if (!call) return reply.code(404).send({ error: 'call_not_found' });
    if (call.status !== 'accepted') return reply.code(409).send({ error: 'call_not_accepted' });

    const user = await db.query(
      'SELECT display_name FROM users WHERE id = $1',
      [request.user.sub],
    );
    const token = new AccessToken(env.LIVEKIT_API_KEY, env.LIVEKIT_API_SECRET, {
      identity: request.user.sub,
      name: user.rows[0]?.display_name as string | undefined,
      ttl: '5m',
    });
    token.addGrant({
      roomJoin: true,
      room: call.room_name,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
    });
    return reply.send({
      serverUrl: env.LIVEKIT_URL,
      accessToken: await token.toJwt(),
      expiresInSeconds: 300,
    });
  });

  app.post('/v1/calls/:callId/end', { preHandler: [app.authenticate] }, async (request, reply) => {
    const callId = idSchema.safeParse((request.params as { callId?: string }).callId);
    if (!callId.success) return reply.code(400).send({ error: 'invalid_call_id' });
    const result = await db.query(
      `UPDATE calls SET status = 'ended', ended_at = now()
       WHERE id = $1 AND (caller_id = $2 OR callee_id = $2)
         AND status IN ('ringing', 'accepted')
       RETURNING id, status`,
      [callId.data, request.user.sub],
    );
    if (!result.rowCount) return reply.code(404).send({ error: 'call_not_available' });
    await db.query(
      `WITH ended_sessions AS (
         UPDATE assistance_sessions SET status = 'ended', ended_at = now()
         WHERE call_id = $1 AND status = 'active'
         RETURNING id
       )
       UPDATE control_requests SET status = 'revoked', revoked_at = now()
       WHERE session_id IN (SELECT id FROM ended_sessions)
         AND status IN ('pending', 'approved')`,
      [callId.data],
    );
    return reply.send({ call: result.rows[0], assistanceRevoked: true });
  });
}
