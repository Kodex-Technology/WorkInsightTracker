# Implementation gap matrix

Generated from repository inspection after the premium UI / admin testing wave. Update as features ship.

| Feature | Current | Missing | Shared Flutter | Windows native | macOS native | Verification |
|---|---|---|---|---|---|---|
| Splash / branding | Done | — | — | — | — | Verified |
| Local auth + restore | Done | Secure storage upgrade optional | Soften prefs→secure later | — | — | Verified |
| Dev admin testing mode | Done (`admin@witrack.local`, `WITRACK_ENV`) | Production admin backend | AppEnv + AuthUser.isDevAdmin | — | — | Analyze pending build |
| Permissions onboarding | Done (basic) | Deeper capability probes | Screens + settings | Capability probes | Screen Recording / Accessibility | Partial |
| Clients / projects / tasks | Done CRUD + dialogs | Client entity polish | Drift + UI | — | — | Analyze pending build |
| Start/pause/resume/stop | Done (Win) | macOS parity | Shared tracking controls | Done | Needs runtime verify | Win partial |
| Idle (5 min, no auto-pause) | Done (Win) | macOS + richer diagnostics | Policy settings | GetLastInputInfo | CGEventSource | Win partial |
| Activity samples | Done (signal model) | Deeper history charts | Sparkline + % | Poll snapshot | Swift poll | Win partial |
| Foreground app | Done (process name) | Usage intervals table, titles policy | Persist intervals | Done | NSWorkspace | Win partial |
| Screenshots | Done | Tray notify polish | Scheduler, encrypt, gallery | GDI+ multi-monitor | CGWindowList (in-repo) | Win build pending this wave |
| Multi-monitor | Partial | Capture-all polish | Metadata | EnumDisplayMonitors | NSScreen | Partial |
| Timeline | Done (events UI) | Richer session bands | Queries + UI | — | — | Analyze pending build |
| Reports / export | Done (local totals) | CSV export | Drift queries | — | — | Analyze pending build |
| Settings | Done (sectioned) | — | Settings repo/UI | updatePolicies | updatePolicies | Analyze pending build |
| Admin policies | Done (local panel + audit) | Remote org policies | Drift + UI | — | — | Analyze pending build |
| Desktop window UX | Done (1180×760, min, persist) | macOS placement | — | Registry placement | Pending | Pending build verify |
| Tray / menu bar | Missing | Background UX | Channel commands | NotifyIcon | NSStatusItem | Pending |
| Lock/sleep signals | Missing | Exclude suspended time | Session events | WTS/power | NSWorkspace wake | Pending |
| Crash recovery | Partial durations | Recover/discard UX | Domain + UI | Heartbeat optional | Same | Pending |
| Manual time | Missing | CRUD + audit | Drift + UI | — | — | Pending |
| Google OAuth | Prepared only | Real PKCE | Auth provider | Browser launch | Browser launch | Not started |
| Sync backend | Outbox not present | Schema + contract | Drift outbox | — | — | Pending |

**Host note:** This development machine is Windows. macOS Swift will be implemented in-repo; runtime verification requires a Mac.
