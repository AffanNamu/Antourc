import type { FastifyInstance } from 'fastify';
import { db } from './db.js';

export async function registerProfileRoutes(app: FastifyInstance): Promise<void> {
  app.get('/v1/auth/me', { preHandler: [app.authenticate] }, async (request, reply) => {
    const result = await db.query(
      'SELECT id, email, display_name, email_verified_at FROM users WHERE id = $1',
      [request.user.sub],
    );
    const user = result.rows[0];
    if (!user || !user.email_verified_at) return reply.code(401).send({ error: 'account_unavailable' });
    return reply.send({
      user: {
        id: user.id,
        email: user.email,
        displayName: user.display_name,
      },
    });
  });
}
