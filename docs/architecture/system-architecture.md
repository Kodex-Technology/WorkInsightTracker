# System architecture (source of truth)

## Principle

Flutter owns UX, session orchestration, persistence, and reporting.  
Native code owns OS signals. Domain code never imports platform-specific APIs.

```text
UI (features) → Riverpod controllers → Domain orchestrator
                                      ↓
                         TrackingEngine (Pigeon interface)
                                      ↓
                    Windows C++  |  macOS Swift (future)
                                      ↓
                         Events → Repositories → Drift / encrypted files
```

## Layers

| Layer | Responsibility |
|---|---|
| `features/` | Screens, widgets, presentation |
| `domain/` | Session state machine, policy application, time math |
| `data/` | Drift DB, repositories, screenshot encryption |
| `platform/` | Pigeon-generated API + thin Dart facade |
| `windows/runner/tracking/` | Canonical Windows C++ engine |
| `macos/` (future) | Swift engine implementing same contract |

## Single app layout (Phase 1)

Monorepo packages are deferred until interfaces stabilize after M3. Current layout:

```text
lib/app|core|domain|data|platform|features
windows/runner/tracking
pigeons/tracking_api.dart   (M3)
```

## Session states

`Stopped → Initializing → Tracking ↔ Idle`  
`Tracking ↔ Paused`  
`Initializing → PermissionRequired | Error`  
`Error → Recovering → Tracking | Stopped`

See [../tracking/tracking-engine.md](../tracking/tracking-engine.md).

## Persistence

Drift/SQLite for structured data; encrypted files for screenshots; secure storage for credentials and encryption keys. Schema: [database-design.md](database-design.md).

## Auth

Provider interface with `LocalDevAuthProvider` (Phase 1) and prepared `GoogleOAuthProvider`. See [authentication.md](authentication.md).
