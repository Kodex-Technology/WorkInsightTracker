export const ROLES = Object.freeze(['user', 'admin', 'super_admin']);

export function normalizeRole(raw) {
  const value = String(raw || 'user').trim().toLowerCase();
  return ROLES.includes(value) ? value : 'user';
}

export function isAdminRole(role) {
  return role === 'admin' || role === 'super_admin';
}

export function mergeClaims(existingClaims, role) {
  const next = { ...(existingClaims || {}) };
  // Preserve unrelated claims; only set role.
  next.role = normalizeRole(role);
  return next;
}

export async function countSuperAdmins(auth) {
  let pageToken;
  let count = 0;
  do {
    const result = await auth.listUsers(1000, pageToken);
    for (const user of result.users) {
      if (user.customClaims?.role === 'super_admin') count += 1;
    }
    pageToken = result.pageToken;
  } while (pageToken);
  return count;
}

export async function assertCanChangeRole({
  auth,
  actorUid,
  actorRole,
  targetUid,
  nextRole,
}) {
  const targetRole = normalizeRole(nextRole);
  if (actorUid === targetUid && targetRole !== 'user' && isAdminRole(targetRole)) {
    // Allow keeping own role; block self-promotion from user→admin.
  }
  if (actorUid === targetUid) {
    const current = await auth.getUser(actorUid);
    const currentRole = normalizeRole(current.customClaims?.role);
    if (currentRole !== targetRole) {
      // Self role change: only super_admin demotion of self is blocked if last.
      if (currentRole === 'super_admin' && targetRole !== 'super_admin') {
        const supers = await countSuperAdmins(auth);
        if (supers <= 1) {
          const err = new Error('Cannot remove the last super_admin.');
          err.status = 400;
          err.code = 'last_super_admin';
          throw err;
        }
      }
      if (!isAdminRole(actorRole) || actorRole !== 'super_admin') {
        const err = new Error('Self role changes require super_admin.');
        err.status = 403;
        err.code = 'self_promotion';
        throw err;
      }
    }
  }

  if (actorRole !== 'super_admin' && targetRole === 'super_admin') {
    const err = new Error('Only super_admin can assign super_admin.');
    err.status = 403;
    err.code = 'forbidden';
    throw err;
  }

  if (actorRole === 'admin' && !['user', 'admin'].includes(targetRole)) {
    const err = new Error('Admin cannot assign that role.');
    err.status = 403;
    throw err;
  }

  const target = await auth.getUser(targetUid);
  const previous = normalizeRole(target.customClaims?.role);
  if (previous === 'super_admin' && targetRole !== 'super_admin') {
    const supers = await countSuperAdmins(auth);
    if (supers <= 1) {
      const err = new Error('Cannot remove the last super_admin.');
      err.status = 400;
      err.code = 'last_super_admin';
      throw err;
    }
  }

  // Prevent ordinary admin from promoting themselves via targetUid trick already covered.
  if (actorUid === targetUid && previous === 'user' && isAdminRole(targetRole)) {
    const err = new Error('Self-promotion is not allowed.');
    err.status = 403;
    err.code = 'self_promotion';
    throw err;
  }

  return { previous, next: targetRole, user: target };
}
