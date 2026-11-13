#!/usr/bin/env node
/**
 * Idempotent admin bootstrap via Firebase Admin SDK.
 * Development only by default. Production requires --allow-production.
 *
 * Usage:
 *   node scripts/bootstrap_admins.mjs --env=development
 *   node scripts/bootstrap_admins.mjs --revoke=email@example.com
 */
import 'dotenv/config';
import { initFirebase, getAuth, getDb } from '../src/firebase.js';
import { mergeClaims, normalizeRole, countSuperAdmins } from '../src/roles.js';

const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, v] = a.replace(/^--/, '').split('=');
    return [k, v ?? true];
  }),
);

const appEnv = args.env || process.env.APP_ENV || 'development';
if (appEnv === 'production' && args['allow-production'] !== true && args['allow-production'] !== 'true') {
  console.error(
    'Refusing production bootstrap without --allow-production (separate approval required).',
  );
  process.exit(1);
}

initFirebase();
const auth = getAuth();
const db = getDb();

const emails = (process.env.ADMIN_BOOTSTRAP_EMAILS || '')
  .split(',')
  .map((e) => e.trim().toLowerCase())
  .filter(Boolean);

if (!emails.length) {
  console.error('ADMIN_BOOTSTRAP_EMAILS is empty.');
  process.exit(1);
}

async function audit(action, target, detail) {
  await db.collection('audit_events').add({
    actorUid: 'bootstrap_script',
    actorEmail: null,
    action,
    target,
    result: 'ok',
    detail,
    at: new Date().toISOString(),
    serverTimestamp: new Date(),
  });
}

async function assign(email, role = 'super_admin') {
  let user;
  try {
    user = await auth.getUserByEmail(email);
  } catch {
    console.error(
      `User not found for ${email}. They must sign in with Google once first.`,
    );
    return { email, status: 'missing' };
  }
  if (!user.emailVerified) {
    console.warn(`Warning: ${email} emailVerified=false; proceeding with Admin lookup.`);
  }
  const previous = normalizeRole(user.customClaims?.role);
  const claims = mergeClaims(user.customClaims, role);
  await auth.setCustomUserClaims(user.uid, claims);
  await audit('bootstrap.role.assign', user.uid, { email, previous, role, appEnv });
  console.log(`Assigned ${role} to ${email} (${user.uid})`);
  return { email, uid: user.uid, status: 'ok', previous, role };
}

async function revoke(email) {
  const user = await auth.getUserByEmail(email);
  const previous = normalizeRole(user.customClaims?.role);
  if (previous === 'super_admin') {
    const supers = await countSuperAdmins(auth);
    if (supers <= 1) {
      throw new Error('Cannot revoke the last super_admin.');
    }
  }
  const claims = mergeClaims(user.customClaims, 'user');
  await auth.setCustomUserClaims(user.uid, claims);
  await audit('bootstrap.role.revoke', user.uid, { email, previous, appEnv });
  console.log(`Revoked admin role for ${email}`);
}

if (args.revoke) {
  await revoke(String(args.revoke).toLowerCase());
  process.exit(0);
}

for (const email of emails) {
  await assign(email, 'super_admin');
}

console.log('Bootstrap complete (idempotent). Users must refresh ID tokens to see new claims.');
