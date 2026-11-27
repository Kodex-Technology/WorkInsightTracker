import admin from 'firebase-admin';
import fs from 'node:fs';
import path from 'node:path';

let initialized = false;

export function initFirebase() {
  if (initialized) return admin;

  const projectId = process.env.FIREBASE_PROJECT_ID || 'witrack-dev';
  const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;

  try {
    if (credPath) {
      const resolved = path.resolve(credPath);
      if (fs.existsSync(resolved)) {
        const serviceAccount = JSON.parse(fs.readFileSync(resolved, 'utf8'));
        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
          projectId,
        });
      } else {
        admin.initializeApp({ projectId });
      }
    } else if (process.env.FIREBASE_AUTH_EMULATOR_HOST) {
      admin.initializeApp({ projectId });
    } else {
      admin.initializeApp({ projectId });
    }
  } catch (e) {
    if (!admin.apps.length) {
      admin.initializeApp({ projectId });
    }
  }

  initialized = true;
  return admin;
}

export function getAuth() {
  return initFirebase().auth();
}

export function getDb() {
  return initFirebase().firestore();
}
