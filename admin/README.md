# Witrack Admin Portal

Single web admin surface (Vite). Verifies Firebase Auth + role claims via the Admin API.

```bash
cp .env.example .env
# Fill VITE_FIREBASE_* from the Firebase web app
npm install
npm run dev
```

Desktop “Open Admin Portal” uses `ADMIN_PORTAL_URL` (default `http://127.0.0.1:5173`).
