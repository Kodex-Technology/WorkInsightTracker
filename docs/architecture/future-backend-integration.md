# Future backend & portal API readiness

**Status:** Contracts + guidelines only. Local tracking remains source of truth. Google auth is **deferred** in the desktop app until a real backend/API is chosen.

## Three separate concerns

1. **Authentication** — local today; future Google / OIDC / portal token via a provider adapter.
2. **Local work tracking** — native engine + Drift (sessions, screenshots, projects). Offline-first.
3. **Official attendance** — future portal check-in/out. Start Tracking ≠ Check-in unless an approved rule says so.

## Dynamic / no-hardcode rules (mandatory)

When a backend arrives:

- Put HTTP/DTOs only in `data/.../adapters/` (or similar). **Never** in `domain/`, `platform/`, or native tracking.
- UI must consume domain models / `ApiResult<T>` — not raw JSON keys from one vendor.
- Prefer **feature flags** (`BACKEND_PROVIDER`, `ENABLE_*`) defaulting off.
- Parse responses with soft helpers (`lib/core/network/api_result.dart`): unknown fields stay in `raw` maps; missing fields must not crash.
- Auth tokens, roles, and policy versions come from the **server** (or verified tokens) — never hardcoded emails/role lists in the client for privilege.
- Screenshots and sessions already store stable local ids + optional `metadataJson` so sync can attach remote ids later without rewriting history.

## Feature flags (every module can be off)

Compile-time flags live in `lib/core/config/feature_flags.dart` (`--dart-define=ENABLE_*=…`):

| Flag | Default | Module |
|---|---|---|
| `ENABLE_CALENDAR` | on | Week/month progress calendar |
| `ENABLE_COMPLETED_LIST` | on | Completed-today list |
| `ENABLE_SCREENSHOTS` | on | Capture + gallery |
| `ENABLE_REPORTS` | on | Reports |
| `ENABLE_TIMELINE` | on | Timeline |
| `ENABLE_PROJECTS_SCREEN` | on | Projects manage screen |
| `ENABLE_BACKEND_SYNC` | **off** | Remote sync adapters |
| `ENABLE_ATTENDANCE` | **off** | Portal check-in |
| `CONFIRM_STOP_BEFORE_MUTATE` | on | Ask before stop on complete/delete |
| `CONFIRM_TASK_SWITCH` | on | Ask before switching live task segment |

Runtime overrides (admin): `featureTogglesProvider` persists per-device flags. **Tracking core** is master and always on.

Nav + routes check runtime toggles. Tracking engine stays local even when sync is off.

## Optimized local → backend flow

1. **Write path:** native engine → Drift sessions (source of truth) → UI clocks.  
2. **Optional sync:** outbox / adapter reads Drift; never the reverse for live timers.  
3. **Aggregations** (`time_totals`, `progress_totals`) take session lists — swap the list source later without UI rewrites.  
4. **Feature off = no route / no nav / no work** for that module; timer logic must remain correct with any subset enabled.

## Day → project → task time tree

Local aggregation lives in `lib/data/tracking/time_totals.dart` (`DayTimeTree` / `TimeBucket`). UI builds from Drift sessions + live segment; a future sync adapter can replace the session list source without changing the tree shape. **Task click** starts/switches; **project click** only browses/selects. Do not hardcode vendor project/task ids in the dashboard.

## Calendar progress

`lib/data/tracking/progress_totals.dart` + `features/calendar` — week/month filters over local sessions (time worked + completed-task counts). Backend can later feed the same `RangeProgress` shape.

## Screenshots (local now, sync-ready)

Saved with: `sessionId`, `projectId`, `taskId`, `takenDay`, encrypted file, optional `metadataJson`.

UI filters: **day**, **project**, **task**. If a future backend omits some filters, local data still remains queryable offline.

## Auth adapter sketch (not implemented)

```text
AuthProvider
  signIn() / signOut() / restore() / refresh()
  → ApiResult<AuthSession>

AuthSession { localUserId, remoteUid?, claims, expiresAt?, raw }
```

Google (or any IdP) becomes one adapter. Switching providers must not require UI rewrites.

## Attendance outcomes

`not_configured` | `loading` | `pending` | `confirmed` | `rejected` | `unauthorized` | `timeout` | `unknown` | `conflict`

Offline local intent ≠ **confirmed** attendance.

## Checklist when API docs arrive

1. OpenAPI, environments, auth scheme, scopes, test credentials  
2. Error envelope, idempotency, time zones, rate limits  
3. UID ↔ employee mapping (never email-only)  
4. One adapter + sandbox tests  
5. Flags off in production until acceptance passes  

## Security

- No service-account keys in desktop builds  
- Native tracking engine never calls remote APIs  
- Privilege checks server-side  
