import Fastify from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import jwt from '@fastify/jwt';
import rateLimit from '@fastify/rate-limit';
import { registerAssistanceRoutes } from './assistance.js';
import { registerAuthRoutes } from './auth.js';
import { registerCallRoutes } from './calls.js';
import { db } from './db.js';
import { env } from './env.js';

const app = Fastify({
  logger: {
    level: env.NODE_ENV === 'production' ? 'info' : 'debug',
    redact: ['req.headers.authorization', 'req.body.password', 'req.body.refreshToken'],
  },
  trustProxy: env.NODE_ENV === 'production',
  bodyLimit: 16 * 1024,
});

await app.register(helmet);
await app.register(cors, {
  origin: env.CORS_ORIGINS.split(',').map((value) => value.trim()).filter(Boolean),
  credentials: true,
});
await app.register(rateLimit, { max: 100, timeWindow: '1 minute' });
await app.register(jwt, { secret: env.ACCESS_TOKEN_SECRET });

app.decorate('authenticate', async (request, reply) => {
  try {
    await request.jwtVerify();
  } catch {
    await reply.code(401).send({ error: 'unauthorized' });
  }
});

app.get('/health/live', async () => ({ status: 'ok' }));
app.get('/health/ready', async (_request, reply) => {
  try {
    await db.query('SELECT 1');
    return { status: 'ready', database: 'connected' };
  } catch {
    return reply.code(503).send({ status: 'not_ready', database: 'unavailable' });
  }
});

await registerAuthRoutes(app);
await registerCallRoutes(app);
await registerAssistanceRoutes(app);

app.setErrorHandler((error, request, reply) => {
  request.log.error({ err: error }, 'Unhandled request error');
  if (reply.sent) return;
  return reply.code(500).send({ error: 'internal_server_error' });
});

const close = async () => {
  await app.close();
  await db.end();
};
process.on('SIGINT', () => void close().then(() => process.exit(0)));
process.on('SIGTERM', () => void close().then(() => process.exit(0)));

try {
  await app.listen({ host: env.HOST, port: env.PORT });
} catch (error) {
  app.log.error(error);
  await close();
  process.exit(1);
}
