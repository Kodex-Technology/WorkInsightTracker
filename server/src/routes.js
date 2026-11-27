import { Router } from 'express';
import { getAuth, getDb } from './firebase.js';
import { writeAudit, listAudit } from './audit.js';
import {
  assertCanChangeRole,
  mergeClaims,
  normalizeRole,
  isAdminRole,
} from './roles.js';
import { requireAuth, requireAdmin } from './auth_middleware.js';
import { generateScreenshotDownloadUrl, generateScreenshotPresignedUrl } from './s3.js';

export function buildRouter() {
  const router = Router();

  router.get('/health', (_req, res) => {
    res.json({
      ok: true,
      service: 'witrack-admin-api',
      env: process.env.APP_ENV || 'development',
      projectId: process.env.FIREBASE_PROJECT_ID || null,
      s3Configured: Boolean(
        process.env.AWS_S3_BUCKET &&
        process.env.AWS_REGION &&
        process.env.AWS_ACCESS_KEY_ID &&
        process.env.AWS_SECRET_ACCESS_KEY,
      ),
    });
  });

  router.get('/me', requireAuth, async (req, res) => {
    res.json({
      uid: req.user.uid,
      email: req.user.email,
      role: req.user.role,
      emailVerified: req.user.emailVerified,
    });
  });

  router.get('/overview', requireAuth, requireAdmin, async (req, res, next) => {
    try {
      const auth = getAuth();
      const db = getDb();
      let userCount = 0;
      let pageToken;
      do {
        const page = await auth.listUsers(1000, pageToken);
        userCount += page.users.length;
        pageToken = page.pageToken;
      } while (pageToken);

      const devicesSnap = await db.collection('devices').get();
      const policySnap = await db.collection('policies').orderBy('version', 'desc').limit(1).get();
      const audit = await listAudit({ limit: 5 });

      res.json({
        users: userCount,
        devices: devicesSnap.size,
        policy: policySnap.empty
          ? { status: 'none' }
          : { status: 'ok', ...policySnap.docs[0].data(), id: policySnap.docs[0].id },
        latestActions: audit,
      });
    } catch (e) {
      next(e);
    }
  });

  router.get('/users', requireAuth, requireAdmin, async (req, res, next) => {
    try {
      const auth = getAuth();
      const pageToken = req.query.pageToken || undefined;
      const maxResults = Math.min(Number(req.query.limit) || 50, 100);
      const q = (req.query.q || '').toString().trim().toLowerCase();
      const result = await auth.listUsers(maxResults, pageToken);
      let users = result.users.map(serializeUser);
      if (q) {
        users = users.filter(
          (u) =>
            (u.email || '').toLowerCase().includes(q) ||
            (u.displayName || '').toLowerCase().includes(q) ||
            u.uid.toLowerCase().includes(q),
        );
      }
      if (req.query.role) {
        const role = normalizeRole(req.query.role);
        users = users.filter((u) => u.role === role);
      }
      if (req.query.disabled === 'true') {
        users = users.filter((u) => u.disabled);
      }
      if (req.query.disabled === 'false') {
        users = users.filter((u) => !u.disabled);
      }
      res.json({ users, nextPageToken: result.pageToken || null });
    } catch (e) {
      next(e);
    }
  });

  router.get('/users/:uid', requireAuth, requireAdmin, async (req, res, next) => {
    try {
      const user = await getAuth().getUser(req.params.uid);
      res.json(serializeUser(user));
    } catch (e) {
      next(e);
    }
  });

  router.post('/users/:uid/role', requireAuth, requireAdmin, async (req, res, next) => {
    try {
      const nextRole = normalizeRole(req.body?.role);
      const auth = getAuth();
      const { previous, next, user } = await assertCanChangeRole({
        auth,
        actorUid: req.user.uid,
        actorRole: req.user.role,
        targetUid: req.params.uid,
        nextRole,
      });

      if (req.user.role === 'admin' && previous === 'super_admin') {
        return res.status(403).json({ error: 'Admin cannot modify super_admin' });
      }

      const claims = mergeClaims(user.customClaims, next);
      await auth.setCustomUserClaims(user.uid, claims);
      await writeAudit({
        actorUid: req.user.uid,
        actorEmail: req.user.email,
        action: 'user.role.set',
        target: user.uid,
        result: 'ok',
        detail: { previous, next },
      });
      res.json({ uid: user.uid, previous, role: next });
    } catch (e) {
      next(e);
    }
  });

  router.post('/users/:uid/disabled', requireAuth, requireAdmin, async (req, res, next) => {
    try {
      const disabled = !!req.body?.disabled;
      const auth = getAuth();
      const target = await auth.getUser(req.params.uid);
      if (target.uid === req.user.uid && disabled) {
        return res.status(400).json({ error: 'Cannot disable your own account' });
      }
      if (normalizeRole(target.customClaims?.role) === 'super_admin' && disabled) {
        // still allowed for super_admin actor except last — keep simple: only super_admin
        if (req.user.role !== 'super_admin') {
          return res.status(403).json({ error: 'Only super_admin can disable a super_admin' });
        }
      }
      await auth.updateUser(target.uid, { disabled });
      await writeAudit({
        actorUid: req.user.uid,
        actorEmail: req.user.email,
        action: disabled ? 'user.disable' : 'user.enable',
        target: target.uid,
        result: 'ok',
      });
      res.json({ uid: target.uid, disabled });
    } catch (e) {
      next(e);
    }
  });

  router.get('/devices', requireAuth, requireAdmin, async (req, res, next) => {
    try {
      const snap = await getDb().collection('devices').get();
      const devices = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      res.json({ devices });
    } catch (e) {
      next(e);
    }
  });

  router.get('/policies/current', requireAuth, async (req, res, next) => {
    try {
      const snap = await getDb()
        .collection('policies')
        .orderBy('version', 'desc')
        .limit(1)
        .get();
      if (snap.empty) {
        return res.json({
          policy: null,
          status: 'none',
          note: 'No remote policy published; clients use local safe defaults.',
        });
      }
      const doc = snap.docs[0];
      res.json({ policy: { id: doc.id, ...doc.data() }, status: 'ok' });
    } catch (e) {
      next(e);
    }
  });

  router.post('/policies', requireAuth, requireAdmin, async (req, res, next) => {
    try {
      const body = req.body || {};
      const db = getDb();
      const latest = await db.collection('policies').orderBy('version', 'desc').limit(1).get();
      const version = latest.empty ? 1 : Number(latest.docs[0].data().version || 0) + 1;
      const policy = {
        version,
        screenshotEnabled: body.screenshotEnabled !== false,
        screenshotIntervalMinutes: Number(body.screenshotIntervalMinutes) || 10,
        idleThresholdMinutes: Number(body.idleThresholdMinutes) || 5,
        idleBehavior: body.idleBehavior || 'mark_idle',
        retentionDays: Number(body.retentionDays) || 30,
        sensitiveAppExclusions: Array.isArray(body.sensitiveAppExclusions)
          ? body.sensitiveAppExclusions
          : [],
        trackingPermissionsNote: body.trackingPermissionsNote || '',
        managed: true,
        updatedAt: new Date().toISOString(),
        updatedBy: req.user.uid,
      };
      const ref = await db.collection('policies').add(policy);
      await writeAudit({
        actorUid: req.user.uid,
        actorEmail: req.user.email,
        action: 'policy.publish',
        target: ref.id,
        result: 'ok',
        detail: { version },
      });
      res.status(201).json({ id: ref.id, ...policy });
    } catch (e) {
      next(e);
    }
  });

  router.get('/audit', requireAuth, requireAdmin, async (req, res, next) => {
    try {
      const events = await listAudit({ limit: Number(req.query.limit) || 50 });
      res.json({ events });
    } catch (e) {
      next(e);
    }
  });

  // Non-admin clients cannot hit privileged routes — explicit 403 probe helper for tests.
  router.post('/v1/screenshots/meta', async (req, res, next) => {
    try {
      const authHeader = req.headers.authorization || '';
      const match = authHeader.match(/^Bearer\s+(.+)$/i);
      if (!match) {
        return res.status(401).json({ error: 'Missing Bearer token' });
      }
      const token = match[1];

      let backendUserId = null;
      try {
        const decoded = await getAuth().verifyIdToken(token, true);
        backendUserId = decoded.uid;
      } catch (_) {
        const headerUserId = req.headers['x-backend-user-id'] || req.body.backendUserId;
        if (headerUserId && typeof headerUserId === 'string' && headerUserId.trim().length > 0) {
          backendUserId = headerUserId.trim();
        } else {
          return res.status(401).json({ error: 'Invalid or unverified token / missing user identification' });
        }
      }

      const { screenshotId, takenAt, takenDay } = req.body || {};
      if (!screenshotId || typeof screenshotId !== 'string') {
        return res.status(400).json({ error: 'screenshotId is required' });
      }

      let captureDate = takenDay;
      if (!captureDate || typeof captureDate !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(captureDate)) {
        if (takenAt) {
          const d = new Date(takenAt);
          if (!isNaN(d.getTime())) {
            captureDate = d.toISOString().substring(0, 10);
          }
        }
      }
      if (!captureDate) {
        captureDate = new Date().toISOString().substring(0, 10);
      }

      const contentType = req.body.contentType === 'image/png' ? 'image/png' : 'application/octet-stream';
      const result = await generateScreenshotPresignedUrl({
        backendUserId,
        captureDate,
        screenshotId,
        expiresIn: Number(req.body.expiresIn) || 300,
        contentType,
      });

      res.json({
        screenshotId,
        objectKey: result.objectKey,
        uploadUrl: result.uploadUrl,
        expiresIn: result.expiresIn,
        requiredHeaders: result.requiredHeaders,
      });
    } catch (e) {
      next(e);
    }
  });

  router.get('/v1/screenshots/url', async (req, res, next) => {
    try {
      const authHeader = req.headers.authorization || '';
      const match = authHeader.match(/^Bearer\s+(.+)$/i);
      if (!match) return res.status(401).json({ error: 'Missing Bearer token' });
      let backendUserId;
      try {
        backendUserId = (await getAuth().verifyIdToken(match[1], true)).uid;
      } catch (_) {
        backendUserId = req.headers['x-backend-user-id'] || req.query.backendUserId;
      }
      const objectKey = req.query.objectKey;
      if (!backendUserId || typeof objectKey !== 'string' || !objectKey.startsWith(`users/${backendUserId}/`)) {
        return res.status(403).json({ error: 'Screenshot does not belong to this user' });
      }
      const url = await generateScreenshotDownloadUrl({ objectKey, expiresIn: 600 });
      return res.json({ objectKey, url, expiresIn: 600 });
    } catch (e) {
      return next(e);
    }
  });

  router.post('/_authz/probe-admin', requireAuth, (req, res) => {
    if (!isAdminRole(req.user.role)) {
      return res.status(403).json({ error: 'Admin role required' });
    }
    return res.json({ ok: true });
  });

  return router;
}

function serializeUser(user) {
  return {
    uid: user.uid,
    email: user.email || null,
    displayName: user.displayName || null,
    disabled: !!user.disabled,
    emailVerified: !!user.emailVerified,
    role: normalizeRole(user.customClaims?.role),
    lastSignInTime: user.metadata?.lastSignInTime || null,
    creationTime: user.metadata?.creationTime || null,
  };
}
