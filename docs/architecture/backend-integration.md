# Backend integration

Tracking remains **offline-first**. Firebase Auth (and the trusted admin API) are identity/admin only — not a general attendance or activity backend.

## Present

- Firebase Authentication for Google sign-in
- Local Admin SDK API + web admin portal (privileged Auth/user ops)
- `sync_outbox` table reserved for future mutations

## Future portal APIs

See [future-backend-integration.md](future-backend-integration.md). Placeholders (`BACKEND_PROVIDER=none`, attendance flags false) do not attach unknown APIs.

## Rules

- Do not hardcode production analytics endpoints.
- Local DB remains source of truth for tracking until an approved sync policy exists.
- Native tracking engine must not call remote portal services directly.
