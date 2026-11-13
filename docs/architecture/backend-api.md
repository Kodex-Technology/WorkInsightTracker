# Backend API (deploy-ready contract)

**Status:** Spec only. Desktop stays offline-first until `ENABLE_BACKEND_SYNC` / auth adapters are on.  
**Rule:** HTTP only in `data/.../adapters/`. Native tracking never calls the network. UI uses `ApiResult<T>` + soft maps — no hardcoded roles/emails.

## What a backend must provide

| Area | Why |
|---|---|
| Auth + tokens | Replace local-only login for production |
| User / org / device | Who owns sessions; revoke devices |
| Projects & tasks sync | Multi-device / admin portal |
| Session + segment sync | Time totals on server |
| Screenshot upload (optional) | Encrypted blob + metadata |
| Policies | Idle / screenshot interval from org |
| Attendance (optional) | Portal check-in ≠ Start Tracking |

## Auth

### `POST /v1/auth/login`

```json
// request
{ "provider": "google|password|portal", "idToken": "...", "deviceId": "uuid" }

// response 200
{
  "accessToken": "jwt",
  "refreshToken": "…",
  "expiresAt": "2026-11-13T12:00:00Z",
  "user": {
    "id": "usr_…",
    "email": "a@b.com",
    "displayName": "Alex",
    "role": "member|admin|manager",
    "orgId": "org_…"
  }
}
```

### `POST /v1/auth/refresh`

```json
{ "refreshToken": "…" }
→ { "accessToken": "jwt", "expiresAt": "…" }
```

### `POST /v1/auth/logout`

```json
{ "refreshToken": "…" }
→ 204
```

### Headers (all authenticated calls)

```http
Authorization: Bearer <accessToken>
X-Device-Id: <uuid>
X-Client: witrack-desktop/1.x
```

## Device

### `POST /v1/devices/register`

```json
{
  "deviceId": "uuid",
  "platform": "windows|macos",
  "appVersion": "1.0.0",
  "hostname": "optional"
}
→ { "deviceId": "uuid", "status": "active" }
```

## Projects & tasks

### `GET /v1/projects?updatedSince=ISO`

```json
{
  "items": [
    {
      "id": "prj_…",
      "name": "General Work",
      "archived": false,
      "updatedAt": "ISO",
      "tasks": [
        { "id": "tsk_…", "name": "task", "completed": false, "updatedAt": "ISO" }
      ]
    }
  ],
  "nextCursor": null
}
```

### `POST /v1/projects` / `POST /v1/projects/{id}/tasks`

Client may send local ids in `clientId` for idempotent upsert.

```json
{ "clientId": "local-uuid", "name": "New project" }
→ { "id": "prj_…", "clientId": "local-uuid" }
```

## Sessions (time sync)

### `POST /v1/sessions/batch` (idempotent upsert)

```json
{
  "items": [
    {
      "clientId": "local-session-uuid",
      "startedAt": "ISO",
      "endedAt": "ISO|null",
      "state": "stopped|tracking|paused|idle",
      "projectId": "prj_…",
      "taskId": "tsk_…",
      "activeMs": 120000,
      "idleMs": 30000,
      "pausedMs": 0,
      "deviceId": "uuid"
    }
  ]
}
→ { "accepted": ["local-session-uuid"], "rejected": [] }
```

### `GET /v1/sessions?from=ISO&to=ISO`

Returns same shape for dashboard/calendar rebuild on another device.

## Screenshots (optional)

### `POST /v1/screenshots/meta` then upload blob

```json
{
  "clientId": "shot-uuid",
  "sessionClientId": "local-session-uuid",
  "takenAt": "ISO",
  "projectId": "prj_…",
  "taskId": "tsk_…",
  "productivityPercent": 74,
  "events": {
    "activityPulses": 12,
    "appSwitches": 3,
    "idleEnters": 1
  },
  "contentHash": "sha256…",
  "encrypted": true
}
→ { "uploadUrl": "https://…signed…", "id": "shot_…" }
```

Upload body: encrypted bytes only. Server never needs plaintext pixels if client encrypts with org key.

## Policies

### `GET /v1/policies`

```json
{
  "idleThresholdSeconds": 300,
  "screenshotIntervalMinutes": 10,
  "autoPauseOnIdle": false,
  "excludedApps": ["1Password"],
  "version": 3
}
```

Client applies via existing `updatePolicies` → native engine.

## Attendance (optional, separate flag)

### `POST /v1/attendance/check-in` / `check-out`

```json
{ "deviceId": "uuid", "at": "ISO", "lat": null, "lng": null }
→ { "status": "confirmed|pending|rejected|unauthorized", "id": "att_…" }
```

Offline local intent ≠ `confirmed`.

## Errors (all endpoints)

```json
{
  "code": "unauthorized|forbidden|validation|conflict|rate_limited|server",
  "message": "Human readable",
  "retryable": false,
  "details": {}
}
```

Map to `ApiFailure` in Dart.

## Security checklist

- TLS only; short-lived access tokens + refresh rotation  
- Server-side role checks (never trust client `role`)  
- No service-account keys in desktop builds  
- Rate-limit auth + upload  
- Screenshot upload: signed URLs, size limits, virus scan optional  
- Audit log for admin policy changes  
- Map users by stable `user.id`, not email alone  

## Client flags

| Flag | Default | Meaning |
|---|---|---|
| `ENABLE_BACKEND_SYNC` | off | Session/project sync adapters |
| `ENABLE_ATTENDANCE` | off | Check-in UI |
| Auth provider | local/dev | Google/OIDC when adapter wired |

## Rollout order

1. Auth + device register  
2. Projects/tasks pull  
3. Session batch sync  
4. Policies pull  
5. Screenshots (optional)  
6. Attendance (optional)  
