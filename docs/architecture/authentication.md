# Authentication

## Current (active)

Compile-time: `--dart-define=WITRACK_ENV=development|production` (`AppEnv`).

| Mode | Local dev login | Local admin testing | Google / Firebase |
|---|---|---|---|
| **development** (default) | Enabled | Enabled (`admin@witrack.local`) | **Deferred — not active** |
| **production** | Disabled | Disabled (fail closed) | Deferred |

Release builds must pass `WITRACK_ENV=production`.

### Development identities

- `dev@witrack.local` — standard local user
- `admin@witrack.local` — Development Admin (local policy testing)

Session: SharedPreferences user id + Drift `users` row. Logout clears the session key.

## Deferred (dynamic when re-enabled)

Google OAuth / Firebase / portal auth are **not wired** into the desktop app for now.

When re-enabled with a real backend:

- Use a provider adapter + `ApiResult` (`lib/core/network/api_result.dart`) — no hardcoded roles/emails in UI.
- Unknown response fields stay in `raw` maps; UI must tolerate missing optional keys.
- See [future-backend-integration.md](future-backend-integration.md).
