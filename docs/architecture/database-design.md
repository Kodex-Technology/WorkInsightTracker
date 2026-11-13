# Database design

Engine: **Drift + SQLite** (local, offline-first). Implemented in M2.

## Tables

| Table | Purpose |
|---|---|
| `users` | Local identity |
| `sessions` | Tracking sessions + aggregated ms |
| `session_events` | State transitions + OS signals |
| `activity_samples` | 10s buckets (kb/mouse counts, score) |
| `app_usage_intervals` | Foreground app segments |
| `screenshots` | Metadata + encrypted path + display id |
| `settings` | Key/value policies |
| `sync_outbox` | Future API sync (schema only in Phase 1) |

## Indexes (planned)

- `activity_samples(session_id, sampled_at)`
- `app_usage_intervals(session_id, started_at)`
- `screenshots(session_id, taken_at)`
- `session_events(session_id, at)`

## Files

Encrypted screenshots under app support `screenshots/`. Key in secure storage.

## Migrations

Drift schema versioning; migration unit tests required from first schema (M2).
