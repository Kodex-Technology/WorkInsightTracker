# Witrack Admin API

Trusted Firebase Admin SDK server for privileged auth operations.

```bash
# Copy .env.example to .env. Configure AWS credentials here (server-side only),
# plus FIREBASE_PROJECT_ID, GOOGLE_APPLICATION_CREDENTIALS, PORT, and
# ADMIN_PORTAL_ORIGIN as needed.
npm ci
npm start
npm test
node scripts/bootstrap_admins.mjs --env=development
```

Listens on `http://127.0.0.1:8787` by default. The desktop app's
`S3_SIGNING_API_BASE_URL` points to this service because its Laravel
`API_BASE_URL` is a separate server. `/api/health` reports whether the S3
environment is configured without returning credential values. AWS keys must
live in this server's `.env` or service environment, never in a desktop build.
Cloud Functions / Hosting deploy is **pending Blaze approval**.
