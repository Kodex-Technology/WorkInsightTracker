# Dependencies

Add packages only when a milestone needs them.

## M0 (current)

| Package | Why |
|---|---|
| `flutter_riverpod` | State management |
| `go_router` | Navigation |

Typography uses bundled **Plus Jakarta Sans** under `assets/fonts/` (no runtime font fetch).

## Added for tracking vertical slice

| Package | Why |
|---|---|
| `drift` + `drift_flutter` | Local SQLite persistence |
| `path_provider` / `path` | DB paths |
| `shared_preferences` | Local auth session restore |
| `uuid` | Session/user ids |
| `intl` | Session list formatting |
| `drift_dev` / `build_runner` | Codegen |

## Firebase Auth (M5c)

| Package | Why |
|---|---|
| `firebase_core` / `firebase_auth` | Google → Firebase identity |
| `cloud_firestore` | Device registry + remote policy reads |
| `http` / `crypto` / `url_launcher` | Desktop PKCE loopback OAuth |
| `flutter_secure_storage` | Screenshot keys (+ platform secure patterns) |

Admin portal/API live under `admin/` and `server/` (Node), not Flutter packages.

## Planned

| Package | Milestone |
|---|---|
| `pigeon` | Optional typed codegen replacing MethodChannel |
| `freezed` / `json_serializable` | Only if model codegen pays off |

Do not add analytics SDKs or DI frameworks without a decision record.
