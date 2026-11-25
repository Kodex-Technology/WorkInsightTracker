# Witrack Admin API

Trusted Firebase Admin SDK server for privileged auth operations.

```bash
# Configure FIREBASE_PROJECT_ID, GOOGLE_APPLICATION_CREDENTIALS,
# PORT, and ADMIN_PORTAL_ORIGIN in your shell or deployment environment.
npm install
npm start
npm test
node scripts/bootstrap_admins.mjs --env=development
```

Listens on `http://127.0.0.1:8787` by default. Cloud Functions / Hosting deploy is **pending Blaze approval**.
