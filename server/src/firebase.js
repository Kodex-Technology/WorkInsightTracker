import admin from 'firebase-admin';
import fs from 'node:fs';
import path from 'node:path';

let initialized = false;

export function initFirebase() {
  if (initialized) return admin;

  const projectId = process.env.FIREBASE_PROJECT_ID;
  const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;

  if (!projectId) {
    throw new Error('FIREBASE_PROJECT_ID is required for the admin API.');
  }

  if (credPath) {
    const resolved = path.resolve(credPath);
    if (!fs.existsSync(resolved)) {
      throw new Error(`Service account file not found: ${resolved}`);
    }
    const serviceAccount = JSON.parse(fs.readFileSync(resolved, 'utf8'));
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId,
    });
  } else if (process.env.FIREBASE_AUTH_EMULATOR_HOST) {
    admin.initializeApp({ projectId });
  } else {
    // Application Default Credentials (CI / GCP)
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId,
    });
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
