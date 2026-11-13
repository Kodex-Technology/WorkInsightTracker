# Weaknesses & readiness

Honest snapshot for deploy planning. Update when gaps close.

## Verdict

| Surface | Ready? |
|---|---|
| Windows desktop tracking (local) | **Strong** — main path |
| macOS native engine | **Code present, not 100% guaranteed** — needs Mac runtime QA |
| Production auth (Google/OIDC) | **Not ready** — local/dev only |
| Cloud backend / sync | **Not ready** — contract only ([backend-api.md](../architecture/backend-api.md)) |
| Attendance portal | **Not ready** — flag off |

**Do not claim macOS “100% all features” until a Mac run passes the checklist below.**

## macOS vs Windows parity

| Feature | Windows | macOS (in-repo) | Notes |
|---|---|---|---|
| MethodChannel `start/pause/resume/stop/poll` | Yes | Yes | Same channel name |
| Idle (5 min, no auto-pause default) | `GetLastInputInfo` | `CGEventSource` | Logic aligned |
| Foreground app | Process name | `NSWorkspace` | OK |
| Multi-display capture | GDI+ | `CGWindowListCreateImage` | Deprecated APIs on new macOS → prefer ScreenCaptureKit later |
| Desktop notices (idle/shot) | Win32 toast | `NSPanel` | Present |
| Screen Recording permission UX | N/A style | Preflight + request | Must verify prompts |
| Tray / menu bar while minimized | Missing both | Missing | Background UX gap |
| Lock / sleep accounting | Missing | Missing | Inflates active time risk |
| Encryption / Drift / UI | Shared Dart | Shared Dart | Same |

### macOS acceptance (must run on Apple hardware)

1. `flutter run -d macos`  
2. Accessibility + Screen Recording prompts OK  
3. Start → idle after threshold → resume on input  
4. Test screenshot → gallery decrypt OK  
5. Idle + screenshot native toasts  
6. Quit/relaunch session restore  
7. Multi-monitor if available  

Until then: **architecture-ready, not verified.**

## App weaknesses (priority)

1. **No production auth** — local emails only; fail-closed in `WITRACK_ENV=production` without Google adapter  
2. **No sync** — data dies with the machine  
3. **Tray missing** — closing window may feel like quit  
4. **Lock/sleep not excluded** from active time  
5. **Crash recovery UX** incomplete  
6. **macOS capture API aging** — ScreenCaptureKit migration needed for longevity  
7. **Sensitive-app exclusions** policy documented; enforcement polish TBD  
8. **Admin is local-only** — no org-wide remote policies  
9. **Export** (CSV/PDF) missing  
10. **Reports removed** — insights only on dashboard rings (by design)

## Security weaknesses

| Risk | Mitigation now / next |
|---|---|
| Local DB readable on disk | OS user isolation; future SQLCipher optional |
| Screenshot keys in secure storage | Keep; never log keys |
| Dev admin identity | Only when `WITRACK_ENV=development` |
| Future API | Server-side authz; short JWT; no keys in client ([backend-api.md](../architecture/backend-api.md)) |
| Privilege escalation via client role field | Never trust; server decides |

## What backend unlocks

- Multi-device same user  
- Manager/admin portal  
- Central idle/screenshot policies  
- Optional screenshot archive  
- Real attendance check-in  
- Revoke lost devices  

Local Drift remains source of truth for live timers; sync is outbox → API, never reverse for the open clock.
