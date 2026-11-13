import { createHash, createHmac, randomBytes, randomInt, timingSafeEqual } from 'node:crypto';
import bcrypt from 'bcryptjs';
import nodemailer from 'nodemailer';
import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { db } from './db.js';
import { env } from './env.js';

const registerSchema = z.object({
  email: z.string().email().max(254),
  displayName: z.string().trim().min(2).max(60),
  password: z.string().min(10).max(128),
});
const verifySchema = z.object({
  email: z.string().email(),
  code: z.string().regex(/^\d{6}$/),
});
const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1).max(128),
});
const refreshSchema = z.object({ refreshToken: z.string().min(32).max(256) });

const hashToken = (token: string) => createHash('sha256').update(token).digest('hex');
const hashOtp = (code: string) => createHmac('sha256', env.OTP_HMAC_SECRET).update(code).digest('hex');

function equalHash(left: string, right: string): boolean {
  const a = Buffer.from(left, 'hex');
  const b = Buffer.from(right, 'hex');
  return a.length === b.length && timingSafeEqual(a, b);
}

function issueAccessToken(app: FastifyInstance, userId: string): string {
  return app.jwt.sign({ sub: userId }, { expiresIn: env.ACCESS_TOKEN_TTL });
}

function createRefreshToken(): string {
  return randomBytes(48).toString('base64url');
}

async function saveRefreshToken(userId: string, token: string): Promise<void> {
  const expires = new Date(Date.now() + env.REFRESH_TOKEN_DAYS * 86_400_000);
  await db.query(
    'INSERT INTO refresh_sessions(user_id, token_hash, expires_at) VALUES ($1, $2, $3)',
    [userId, hashToken(token), expires],
  );
}

async function sendVerificationEmail(email: string, code: string): Promise<void> {
  if (!env.SMTP_HOST || !env.SMTP_USER || !env.SMTP_PASSWORD) {
    throw new Error('Email verification is not configured on this server.');
  }
  const transport = nodemailer.createTransport({
    host: env.SMTP_HOST,
    port: env.SMTP_PORT,
    secure: env.SMTP_SECURE,
    auth: { user: env.SMTP_USER, pass: env.SMTP_PASSWORD },
  });
  await transport.sendMail({
    from: env.SMTP_FROM,
    to: email,
    subject: 'Verify your AssistLink account',
    text: `Your AssistLink verification code is ${code}. It expires in 10 minutes. If you did not request this, ignore this email.`,
  });
}

export async function registerAuthRoutes(app: FastifyInstance): Promise<void> {
  app.post('/v1/auth/register', async (request, reply) => {
    const parsed = registerSchema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'invalid_request', details: parsed.error.flatten() });

    const email = parsed.data.email.trim().toLowerCase();
    const passwordHash = await bcrypt.hash(parsed.data.password, 12);
    const code = String(randomInt(100_000, 1_000_000));
    const client = await db.connect();

    try {
      await client.query('BEGIN');
      const inserted = await client.query(
        'INSERT INTO users(email, display_name, password_hash) VALUES ($1, $2, $3) RETURNING id',
        [email, parsed.data.displayName, passwordHash],
      );
      const userId = inserted.rows[0].id as string;
      await client.query(
        `INSERT INTO email_verifications(user_id, code_hash, expires_at)
         VALUES ($1, $2, now() + interval '10 minutes')`,
        [userId, hashOtp(code)],
      );
      await client.query('COMMIT');
      await sendVerificationEmail(email, code);
      return reply.code(202).send({ status: 'verification_required' });
    } catch (error) {
      await client.query('ROLLBACK').catch(() => undefined);
      if (error instanceof Error && error.message.includes('Email verification is not configured')) {
        return reply.code(503).send({ error: 'email_verification_unavailable' });
      }
      if (typeof error === 'object' && error !== null && 'code' in error && error.code === '23505') {
        return reply.code(409).send({ error: 'account_already_exists' });
      }
      request.log.error({ err: error }, 'Registration failed');
      return reply.code(500).send({ error: 'registration_failed' });
    } finally {
      client.release();
    }
  });

  app.post('/v1/auth/verify-email', async (request, reply) => {
    const parsed = verifySchema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'invalid_request' });
    const email = parsed.data.email.trim().toLowerCase();
    const client = await db.connect();
    try {
      await client.query('BEGIN');
      const result = await client.query(
        `SELECT u.id, v.code_hash, v.expires_at, v.attempts
         FROM users u JOIN email_verifications v ON v.user_id = u.id
         WHERE u.email = $1 FOR UPDATE OF v`,
        [email],
      );
      const row = result.rows[0];
      if (!row) {
        await client.query('ROLLBACK');
        return reply.code(400).send({ error: 'invalid_or_expired_code' });
      }
      if (new Date(row.expires_at).getTime() < Date.now() || row.attempts >= 5) {
        await client.query('DELETE FROM email_verifications WHERE user_id = $1', [row.id]);
        await client.query('COMMIT');
        return reply.code(400).send({ error: 'invalid_or_expired_code' });
      }
      if (!equalHash(hashOtp(parsed.data.code), row.code_hash as string)) {
        await client.query(
          'UPDATE email_verifications SET attempts = attempts + 1 WHERE user_id = $1',
          [row.id],
        );
        await client.query('COMMIT');
        return reply.code(400).send({ error: 'invalid_or_expired_code' });
      }
      await client.query('UPDATE users SET email_verified_at = now() WHERE id = $1', [row.id]);
      await client.query('DELETE FROM email_verifications WHERE user_id = $1', [row.id]);
      await client.query('COMMIT');
      return reply.send({ status: 'verified' });
    } catch (error) {
      await client.query('ROLLBACK').catch(() => undefined);
      request.log.error({ err: error }, 'Email verification failed');
      return reply.code(500).send({ error: 'verification_failed' });
    } finally {
      client.release();
    }
  });

  app.post('/v1/auth/login', async (request, reply) => {
    const parsed = loginSchema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'invalid_request' });
    const email = parsed.data.email.trim().toLowerCase();
    const result = await db.query(
      'SELECT id, display_name, password_hash, email_verified_at FROM users WHERE email = $1',
      [email],
    );
    const user = result.rows[0];
    if (!user || !(await bcrypt.compare(parsed.data.password, user.password_hash as string))) {
      return reply.code(401).send({ error: 'invalid_credentials' });
    }
    if (!user.email_verified_at) return reply.code(403).send({ error: 'email_verification_required' });

    const refreshToken = createRefreshToken();
    await saveRefreshToken(user.id as string, refreshToken);
    return reply.send({
      accessToken: issueAccessToken(app, user.id as string),
      refreshToken,
      tokenType: 'Bearer',
      expiresInSeconds: 900,
      user: { id: user.id, displayName: user.display_name, email },
    });
  });

  app.post('/v1/auth/refresh', async (request, reply) => {
    const parsed = refreshSchema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'invalid_request' });
    const oldHash = hashToken(parsed.data.refreshToken);
    const client = await db.connect();
    try {
      await client.query('BEGIN');
      const result = await client.query(
        'SELECT id, user_id FROM refresh_sessions WHERE token_hash = $1 AND expires_at > now() FOR UPDATE',
        [oldHash],
      );
      const session = result.rows[0];
      if (!session) {
        await client.query('ROLLBACK');
        return reply.code(401).send({ error: 'invalid_refresh_token' });
      }
      await client.query('DELETE FROM refresh_sessions WHERE id = $1', [session.id]);
      const refreshToken = createRefreshToken();
      const expires = new Date(Date.now() + env.REFRESH_TOKEN_DAYS * 86_400_000);
      await client.query(
        'INSERT INTO refresh_sessions(user_id, token_hash, expires_at) VALUES ($1, $2, $3)',
        [session.user_id, hashToken(refreshToken), expires],
      );
      await client.query('COMMIT');
      return reply.send({
        accessToken: issueAccessToken(app, session.user_id as string),
        refreshToken,
        tokenType: 'Bearer',
        expiresInSeconds: 900,
      });
    } catch (error) {
      await client.query('ROLLBACK').catch(() => undefined);
      request.log.error({ err: error }, 'Refresh rotation failed');
      return reply.code(500).send({ error: 'refresh_failed' });
    } finally {
      client.release();
    }
  });

  app.post('/v1/auth/logout', { preHandler: [app.authenticate] }, async (request, reply) => {
    const parsed = refreshSchema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'invalid_request' });
    await db.query(
      'DELETE FROM refresh_sessions WHERE user_id = $1 AND token_hash = $2',
      [request.user.sub, hashToken(parsed.data.refreshToken)],
    );
    return reply.code(204).send();
  });
}

export async function authenticate(request: FastifyRequest, reply: FastifyReply): Promise<void> {
  try {
    await request.jwtVerify();
  } catch {
    await reply.code(401).send({ error: 'unauthorized' });
  }
}
