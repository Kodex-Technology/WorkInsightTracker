import { getAuth } from './firebase.js';
import { isAdminRole, normalizeRole } from './roles.js';

export async function requireAuth(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const match = header.match(/^Bearer\s+(.+)$/i);
    if (!match) {
      return res.status(401).json({ error: 'Missing Bearer token' });
    }
    const decoded = await getAuth().verifyIdToken(match[1], true);
    req.user = {
      uid: decoded.uid,
      email: decoded.email || null,
      emailVerified: !!decoded.email_verified,
      role: normalizeRole(decoded.role),
      claims: decoded,
    };
    return next();
  } catch (e) {
    return res.status(401).json({ error: 'Invalid or expired token', detail: e.message });
  }
}

export function requireAdmin(req, res, next) {
  if (!req.user || !isAdminRole(req.user.role)) {
    return res.status(403).json({ error: 'Admin role required' });
  }
  return next();
}

export function requireSuperAdmin(req, res, next) {
  if (!req.user || req.user.role !== 'super_admin') {
    return res.status(403).json({ error: 'super_admin role required' });
  }
  return next();
}
