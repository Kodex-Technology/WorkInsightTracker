import { getDb } from './firebase.js';

export async function writeAudit({
  actorUid,
  actorEmail,
  action,
  target,
  result,
  detail,
}) {
  const db = getDb();
  const doc = {
    actorUid: actorUid || null,
    actorEmail: actorEmail || null,
    action,
    target: target || null,
    result: result || 'ok',
    detail: detail || null,
    at: new Date().toISOString(),
    serverTimestamp: adminTimestamp(),
  };
  const ref = await db.collection('audit_events').add(doc);
  return { id: ref.id, ...doc };
}

function adminTimestamp() {
  // Lazy import avoidance — store ISO; Admin SDK Timestamp optional.
  return new Date();
}

export async function listAudit({ limit = 50 } = {}) {
  const db = getDb();
  const snap = await db
    .collection('audit_events')
    .orderBy('at', 'desc')
    .limit(Math.min(limit, 200))
    .get();
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}
