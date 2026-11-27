# Firebase setup (Witrack)

Guided procedure for **real** Google Authentication via Firebase on Windows and macOS. Emulator Suite may help with Admin API tests; it is **not** a substitute for a real Google sign-in smoke test.

## Prerequisites

1. Flutter stable (desktop enabled for Windows; macOS when verifying on Apple hardware).
2. Node.js 20+ (Admin API + portal).
3. Firebase CLI: `npm install -g firebase-tools` (needs free disk) then `firebase login`.
4. FlutterFire CLI optional for web admin config (`dart pub global activate flutterfire_cli`). Desktop auth uses **Google PKCE + Firebase Identity Toolkit REST** (no FlutterFire C++ SDK on Windows).
5. Google Cloud / Firebase project permissions for **two** isolated projects.

**Billing:** Auth + Firestore Spark may be enough for early admin. **Blaze is required** for Cloud Functions / some Hosting+Functions combos. Do **not** upgrade or deploy paid services without explicit approval. Part 1 ships a **local Admin SDK server** so privileged ops work without Cloud Functions.

## 1. Create two Firebase projects

| Env | Suggested project ID | Notes |
|---|---|---|
| Development | `witrack-dev` (must be unique) | Bootstrap admins allowed |
| Production | `witrack-prod` (must be unique) | Separate OAuth, Auth, Firestore, service accounts |

Never point a production build at the development project.

```bash
firebase projects:create witrack-dev --display-name "Witrack Dev"
firebase projects:create witrack-prod --display-name "Witrack Prod"
```

If CLI create fails (quota/permissions), create both projects in the [Firebase Console](https://console.firebase.google.com/).

## 2. Register apps

For **each** project:

1. Add a **Web** app (admin portal) — copy `apiKey`, `authDomain`, `projectId`, `appId`, `messagingSenderId`, `storageBucket`.
2. Add Windows / macOS apps if FlutterFire configure requires them.

```bash
firebase use witrack-dev
dart pub global run flutterfire_cli:flutterfire configure --project=witrack-dev --platforms=windows,macos,web --yes
```

Desktop API routing is configured separately through `.env` / `.env.production`; do not put API endpoints in dart-defines. Firebase client setup remains deferred for the current desktop auth flow.

## 3. Google provider + desktop OAuth client

In **each** Firebase project → Authentication → Sign-in method → enable **Google**.

In Google Cloud Console (same project) → APIs & Services → Credentials:

1. Create OAuth client ID type **Desktop app**.
2. Copy client ID into `GOOGLE_OAUTH_DESKTOP_CLIENT_ID` (public client; **no client secret** in the desktop app).
3. Authorized redirect URIs must allow loopback, e.g. `http://127.0.0.1` / `http://localhost` (Google desktop clients typically allow loopback with any port for installed apps). Witrack listens on `http://127.0.0.1:<ephemeral>/callback`.

## 4. Firestore

1. Create Firestore (Native mode) in each project.
2. Deploy rules from [`firestore.rules`](../../firestore.rules).
3. Add indexes only when the console or deploy reports a need (users/devices/policies/audit as implemented).

## 5. Admin portal + Admin API (local first)

```bash
cd server
# Set FIREBASE_PROJECT_ID and GOOGLE_APPLICATION_CREDENTIALS in the server environment.
npm install
npm start

cd ../admin
npm install
npm run dev
```

Set desktop `ADMIN_PORTAL_URL` / `ADMIN_API_BASE_URL` accordingly.

**Cloud Hosting / Functions deploy:** pending Blaze approval. Document only until approved.

## 6. Service account (server only)

1. Project Settings → Service accounts → Generate new private key.
2. Store under `secrets/` (gitignored) or OS secret store.
3. Never embed Admin SDK keys in Flutter assets or dart-defines.

## 7. Bootstrap development admins

After each bootstrap email has signed in once with Google (user exists in Firebase Auth):

```bash
cd server
node scripts/bootstrap_admins.mjs --env=development
```

Default emails: `kodextech9@gmail.com`, `zainskodex@gmail.com` → `super_admin` custom claims.

**Production bootstrap** requires a separate explicit approval; do not reuse the development script against prod without that approval.

## 8. Desktop dart-defines

Use `.env` for development. Production packages use `.env.production` and must set `APP_ENV=production`; see [windows-build.md](windows-build.md).

## 9. Windows real Google sign-in smoke test

1. Launch with development configuration in `.env`.
2. Login → **Continue with Google** → system browser opens (not an embedded WebView).
3. Pick account → consent → browser returns to loopback → app shows validating → dashboard.
4. Restart app → session restores with same Firebase UID.
5. Confirm local tracking still starts/stops without network.

## 10. macOS verification checklist (when on a Mac)

1. Same `.env` configuration (or macOS-specific app id if registered separately).
2. Allow local networking / loopback for the callback listener.
3. Repeat smoke steps 2–5 from Windows section.
4. Mark macOS runtime **passed** only after this checklist succeeds on hardware. Windows-only development leaves macOS **pending**.

## Diagnostics without credentials

If Firebase/OAuth fields are empty, Witrack shows a **setup missing** state on the login screen, lists missing keys (no secrets), and keeps development local login available when `ENABLE_LOCAL_DEV_AUTH=true`. Tracking features stay operational for local sessions.
