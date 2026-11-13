import { readFile } from 'node:fs/promises';
import { db } from './db.js';

try {
  const sql = await readFile(new URL('../migrations/001_initial.sql', import.meta.url), 'utf8');
  await db.query(sql);
  process.stdout.write('Database migrations completed.\n');
} finally {
  await db.end();
}
