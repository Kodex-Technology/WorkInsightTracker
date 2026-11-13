import { adminConfig, idToken } from './firebase.js';

async function request(path, options = {}) {
  const token = await idToken(options.forceRefresh === true);
  if (!token) {
    const err = new Error('Not signed in');
    err.status = 401;
    throw err;
  }
  const res = await fetch(`${adminConfig.apiBase}/api${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
      ...(options.headers || {}),
    },
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = new Error(data.error || `Request failed (${res.status})`);
    err.status = res.status;
    err.code = data.code;
    throw err;
  }
  return data;
}

export const api = {
  me: () => request('/me', { forceRefresh: true }),
  overview: () => request('/overview'),
  users: (qs = '') => request(`/users${qs}`),
  setRole: (uid, role) =>
    request(`/users/${uid}/role`, {
      method: 'POST',
      body: JSON.stringify({ role }),
    }),
  setDisabled: (uid, disabled) =>
    request(`/users/${uid}/disabled`, {
      method: 'POST',
      body: JSON.stringify({ disabled }),
    }),
  devices: () => request('/devices'),
  policy: () => request('/policies/current'),
  publishPolicy: (body) =>
    request('/policies', { method: 'POST', body: JSON.stringify(body) }),
  audit: () => request('/audit?limit=100'),
};
