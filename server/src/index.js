import dotenv from 'dotenv';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import cors from 'cors';
import express from 'express';
import { initFirebase } from './firebase.js';
import { buildRouter } from './routes.js';

const serverDir = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(serverDir, '../.env') });

const port = Number(process.env.PORT) || 8787;
const origin = process.env.ADMIN_PORTAL_ORIGIN || 'http://127.0.0.1:5173';

try {
  initFirebase();
} catch (e) {
  console.warn('Firebase Admin init warning (proceeding with fallback):', e.message);
}

const app = express();
app.use(
  cors({
    origin: [origin, 'http://localhost:5173', 'http://127.0.0.1:5173'],
    credentials: true,
  }),
);
app.use(express.json({ limit: '1mb' }));
app.use('/api', buildRouter());

app.use((err, _req, res, _next) => {
  const status = err.status || 500;
  res.status(status).json({
    error: err.message || 'Internal error',
    code: err.code || undefined,
  });
});

app.listen(port, '127.0.0.1', () => {
  console.log(
    `Witrack admin API listening on http://127.0.0.1:${port} (${process.env.APP_ENV || 'development'} / ${process.env.FIREBASE_PROJECT_ID})`,
  );
});
