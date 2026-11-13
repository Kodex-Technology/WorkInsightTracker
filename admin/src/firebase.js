import { initializeApp } from 'firebase/app';
import {
  getAuth,
  GoogleAuthProvider,
  signInWithPopup,
  signOut,
  onAuthStateChanged,
} from 'firebase/auth';

function readConfig() {
  // Injected at build/dev time via window.__WITRACK_ADMIN__ or import.meta.env
  const cfg = window.__WITRACK_ADMIN__ || {
    apiKey: import.meta.env.VITE_FIREBASE_API_KEY || '',
    authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN || '',
    projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID || '',
    appId: import.meta.env.VITE_FIREBASE_APP_ID || '',
    messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID || '',
  };
  return cfg;
}

export const adminConfig = {
  apiBase: import.meta.env.VITE_ADMIN_API_BASE_URL || 'http://127.0.0.1:8787',
  firebase: readConfig(),
};

let app;
let auth;

export function ensureFirebase() {
  const c = adminConfig.firebase;
  if (!c.apiKey || !c.projectId || !c.appId || !c.authDomain) {
    return { ok: false, reason: 'Firebase web config missing (VITE_FIREBASE_*).' };
  }
  if (!app) {
    app = initializeApp(c);
    auth = getAuth(app);
  }
  return { ok: true, auth };
}

export async function signInGoogle() {
  const ready = ensureFirebase();
  if (!ready.ok) throw new Error(ready.reason);
  const provider = new GoogleAuthProvider();
  provider.setCustomParameters({ prompt: 'select_account' });
  return signInWithPopup(ready.auth, provider);
}

export async function logout() {
  const ready = ensureFirebase();
  if (!ready.ok) return;
  await signOut(ready.auth);
}

export function watchAuth(cb) {
  const ready = ensureFirebase();
  if (!ready.ok) {
    cb(null, ready.reason);
    return () => {};
  }
  return onAuthStateChanged(ready.auth, (user) => cb(user, null));
}

export async function idToken(forceRefresh = false) {
  const ready = ensureFirebase();
  if (!ready.ok || !ready.auth.currentUser) return null;
  return ready.auth.currentUser.getIdToken(forceRefresh);
}
