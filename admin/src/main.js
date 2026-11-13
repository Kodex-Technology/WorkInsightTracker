import { api } from './api.js';
import {
  adminConfig,
  ensureFirebase,
  logout,
  signInGoogle,
  watchAuth,
} from './firebase.js';

const app = document.getElementById('app');
let state = {
  user: null,
  me: null,
  view: 'overview',
  error: null,
  setupError: null,
  loading: true,
  data: {},
};

function set(partial) {
  state = { ...state, ...partial };
  render();
}

watchAuth(async (user, setupError) => {
  if (setupError) {
    set({ user: null, me: null, setupError, loading: false });
    return;
  }
  if (!user) {
    set({ user: null, me: null, loading: false, error: null });
    return;
  }
  set({ user, loading: true, setupError: null });
  try {
    const me = await api.me();
    if (me.role !== 'admin' && me.role !== 'super_admin') {
      set({
        user,
        me,
        loading: false,
        error: 'Signed in, but this account is not an admin.',
      });
      return;
    }
    set({ user, me, loading: false, error: null });
    await loadView(state.view);
  } catch (e) {
    set({ loading: false, error: e.message });
  }
});

async function loadView(view) {
  set({ view, loading: true, error: null });
  try {
    let data = {};
    if (view === 'overview') data = { overview: await api.overview() };
    if (view === 'users') data = { users: await api.users('?limit=50') };
    if (view === 'devices') data = { devices: await api.devices() };
    if (view === 'policies') data = { policy: await api.policy() };
    if (view === 'audit') data = { audit: await api.audit() };
    set({ data, loading: false });
  } catch (e) {
    set({ loading: false, error: e.message });
  }
}

function render() {
  if (state.setupError || !ensureFirebase().ok) {
    app.innerHTML = `
      <div class="auth"><div class="card auth-card">
        <div class="brand"><div class="mark">W</div><div>Witrack Admin</div></div>
        <p class="muted">Firebase web configuration is missing.</p>
        <p class="error">${escapeHtml(state.setupError || 'Set VITE_FIREBASE_* in admin/.env')}</p>
        <p class="muted">API: ${escapeHtml(adminConfig.apiBase)}</p>
      </div></div>`;
    return;
  }

  if (!state.user) {
    app.innerHTML = `
      <div class="auth"><div class="card auth-card">
        <div class="brand"><div class="mark">W</div><div>Witrack Admin</div></div>
        <p class="muted">Sign in with Google. Role claims are verified by the Admin API independently of the desktop app.</p>
        <button class="btn" id="google">Continue with Google</button>
        ${state.error ? `<p class="error">${escapeHtml(state.error)}</p>` : ''}
      </div></div>`;
    document.getElementById('google').onclick = async () => {
      try {
        await signInGoogle();
      } catch (e) {
        set({ error: e.message });
      }
    };
    return;
  }

  if (state.me && state.me.role !== 'admin' && state.me.role !== 'super_admin') {
    app.innerHTML = `
      <div class="auth"><div class="card auth-card">
        <h2>Unauthorized</h2>
        <p class="muted">${escapeHtml(state.user.email || '')}</p>
        <p class="error">This account does not have an admin role claim.</p>
        <button class="btn secondary" id="out">Sign out</button>
      </div></div>`;
    document.getElementById('out').onclick = () => logout();
    return;
  }

  const nav = ['overview', 'users', 'devices', 'policies', 'audit']
    .map(
      (v) =>
        `<button class="${state.view === v ? 'active' : ''}" data-view="${v}">${label(v)}</button>`,
    )
    .join('');

  app.innerHTML = `
    <div class="shell">
      <aside class="sidebar">
        <div class="brand"><div class="mark">W</div><div>Witrack Admin</div></div>
        <div class="nav">${nav}</div>
        <div style="padding:12px 8px" class="muted">${escapeHtml(state.me?.email || '')}<br/>${escapeHtml(state.me?.role || '')}</div>
        <button class="btn secondary" id="out" style="width:100%">Sign out</button>
      </aside>
      <main class="main">
        ${state.error ? `<p class="error">${escapeHtml(state.error)}</p>` : ''}
        ${state.loading ? '<p class="muted">Loading…</p>' : renderView()}
      </main>
    </div>`;

  document.getElementById('out').onclick = () => logout();
  document.querySelectorAll('[data-view]').forEach((btn) => {
    btn.onclick = () => loadView(btn.dataset.view);
  });
  wireViewActions();
}

function renderView() {
  if (state.view === 'overview') {
    const o = state.data.overview || {};
    return `
      <h1>Overview</h1>
      <p class="muted">Live counts from Firebase Auth / Firestore — no invented analytics.</p>
      <div class="grid" style="margin-top:12px">
        <div class="stat"><span class="muted">Users</span><strong>${o.users ?? '—'}</strong></div>
        <div class="stat"><span class="muted">Registered devices</span><strong>${o.devices ?? '—'}</strong></div>
        <div class="stat"><span class="muted">Policy</span><strong>${escapeHtml(o.policy?.status || '—')}</strong></div>
      </div>
      <div class="card" style="margin-top:16px">
        <h3>Latest authorized actions</h3>
        ${renderAuditRows(o.latestActions || [])}
      </div>`;
  }

  if (state.view === 'users') {
    const users = state.data.users?.users || [];
    return `
      <h1>Users</h1>
      <div class="toolbar">
        <input id="q" placeholder="Search email / UID" />
        <button class="btn secondary" id="search">Search</button>
      </div>
      <div class="card"><table>
        <thead><tr><th>Email</th><th>Role</th><th>Status</th><th>Last sign-in</th><th></th></tr></thead>
        <tbody>
          ${users
            .map(
              (u) => `<tr>
              <td>${escapeHtml(u.email || u.uid)}<div class="muted">${escapeHtml(u.uid)}</div></td>
              <td>
                <select data-role="${u.uid}">
                  ${['user', 'admin', 'super_admin']
                    .map(
                      (r) =>
                        `<option value="${r}" ${u.role === r ? 'selected' : ''}>${r}</option>`,
                    )
                    .join('')}
                </select>
              </td>
              <td>${u.disabled ? 'disabled' : 'active'}</td>
              <td>${escapeHtml(u.lastSignInTime || '—')}</td>
              <td>
                <button class="btn secondary" data-toggle="${u.uid}" data-disabled="${u.disabled}">${u.disabled ? 'Enable' : 'Disable'}</button>
              </td>
            </tr>`,
            )
            .join('')}
        </tbody>
      </table></div>`;
  }

  if (state.view === 'devices') {
    const devices = state.data.devices?.devices || [];
    return `
      <h1>Device registry</h1>
      <p class="muted">Only devices that have registered with Firebase UID + environment. Offline / not-yet-registered devices do not appear.</p>
      <div class="card"><table>
        <thead><tr><th>Name</th><th>Platform</th><th>UID</th><th>Env</th><th>Last seen</th></tr></thead>
        <tbody>
          ${
            devices.length
              ? devices
                  .map(
                    (d) => `<tr>
                <td>${escapeHtml(d.name || d.id)}</td>
                <td>${escapeHtml(d.platform || '—')}</td>
                <td>${escapeHtml(d.firebaseUid || '—')}</td>
                <td>${escapeHtml(d.environment || '—')}</td>
                <td>${escapeHtml(d.lastSeenAt || '—')}</td>
              </tr>`,
                  )
                  .join('')
              : '<tr><td colspan="5" class="muted">No registered devices yet</td></tr>'
          }
        </tbody>
      </table></div>`;
  }

  if (state.view === 'policies') {
    const p = state.data.policy?.policy;
    return `
      <h1>Policies</h1>
      <p class="muted">Remote admin-managed policy (versioned). Clients keep local safe defaults when offline or unset.</p>
      <div class="card">
        <p>Status: <strong>${escapeHtml(state.data.policy?.status || '—')}</strong>
        ${p ? ` · version ${p.version}` : ''}</p>
        <div class="form-grid">
          <label>Screenshot enabled
            <select id="screenshotEnabled">
              <option value="true" ${!p || p.screenshotEnabled !== false ? 'selected' : ''}>true</option>
              <option value="false" ${p && p.screenshotEnabled === false ? 'selected' : ''}>false</option>
            </select>
          </label>
          <label>Screenshot interval (minutes)
            <input id="screenshotIntervalMinutes" type="number" value="${p?.screenshotIntervalMinutes ?? 10}" />
          </label>
          <label>Idle threshold (minutes)
            <input id="idleThresholdMinutes" type="number" value="${p?.idleThresholdMinutes ?? 5}" />
          </label>
          <label>Idle behavior
            <input id="idleBehavior" value="${escapeHtml(p?.idleBehavior || 'mark_idle')}" />
          </label>
          <label>Retention days
            <input id="retentionDays" type="number" value="${p?.retentionDays ?? 30}" />
          </label>
          <label>Sensitive app exclusions (comma-separated)
            <input id="exclusions" value="${escapeHtml((p?.sensitiveAppExclusions || []).join(', '))}" />
          </label>
          <button class="btn" id="publish">Publish new policy version</button>
        </div>
      </div>`;
  }

  if (state.view === 'audit') {
    return `<h1>Audit</h1><div class="card">${renderAuditRows(state.data.audit?.events || [])}</div>`;
  }

  return '';
}

function renderAuditRows(events) {
  if (!events.length) return '<p class="muted">No audit events yet.</p>';
  return `<table><thead><tr><th>When</th><th>Actor</th><th>Action</th><th>Target</th><th>Result</th></tr></thead><tbody>
    ${events
      .map(
        (e) => `<tr>
      <td>${escapeHtml(e.at || '')}</td>
      <td>${escapeHtml(e.actorEmail || e.actorUid || '')}</td>
      <td>${escapeHtml(e.action || '')}</td>
      <td>${escapeHtml(e.target || '')}</td>
      <td>${escapeHtml(e.result || '')}</td>
    </tr>`,
      )
      .join('')}
  </tbody></table>`;
}

function wireViewActions() {
  const search = document.getElementById('search');
  if (search) {
    search.onclick = async () => {
      const q = document.getElementById('q').value.trim();
      set({ loading: true });
      try {
        const users = await api.users(`?limit=50&q=${encodeURIComponent(q)}`);
        set({ data: { users }, loading: false });
      } catch (e) {
        set({ error: e.message, loading: false });
      }
    };
  }

  document.querySelectorAll('[data-role]').forEach((sel) => {
    sel.onchange = async () => {
      try {
        await api.setRole(sel.dataset.role, sel.value);
        await loadView('users');
      } catch (e) {
        set({ error: e.message });
      }
    };
  });

  document.querySelectorAll('[data-toggle]').forEach((btn) => {
    btn.onclick = async () => {
      try {
        const disabled = btn.dataset.disabled === 'true';
        await api.setDisabled(btn.dataset.toggle, !disabled);
        await loadView('users');
      } catch (e) {
        set({ error: e.message });
      }
    };
  });

  const publish = document.getElementById('publish');
  if (publish) {
    publish.onclick = async () => {
      try {
        await api.publishPolicy({
          screenshotEnabled: document.getElementById('screenshotEnabled').value === 'true',
          screenshotIntervalMinutes: Number(
            document.getElementById('screenshotIntervalMinutes').value,
          ),
          idleThresholdMinutes: Number(
            document.getElementById('idleThresholdMinutes').value,
          ),
          idleBehavior: document.getElementById('idleBehavior').value,
          retentionDays: Number(document.getElementById('retentionDays').value),
          sensitiveAppExclusions: document
            .getElementById('exclusions')
            .value.split(',')
            .map((s) => s.trim())
            .filter(Boolean),
        });
        await loadView('policies');
      } catch (e) {
        set({ error: e.message });
      }
    };
  }
}

function label(v) {
  return v[0].toUpperCase() + v.slice(1);
}

function escapeHtml(s) {
  return String(s)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

render();
