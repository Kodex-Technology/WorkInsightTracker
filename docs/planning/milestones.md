# Milestones (source of truth)

Baseline plan: Cursor plan `witrack_phase_1` (high-level reference). Detailed specs live under `docs/`.

| ID | Name | Status | Acceptance |
|---|---|---|---|
| M0 | Foundation | **Complete** | Branded splash→shell; docs; analyze clean; Windows verify |
| M1 | Local auth + routes | **Complete** (essential) | Local login; session restore; auth gate |
| M2 | Drift + settings | **Advanced** | Expanded schema + settings UI wired to engine policies |
| M3 | Windows native engine | **Advanced** | Lifecycle + idle + apps + capture; tray still pending |
| M4 | Screenshots | **Advanced** | Real Win capture + encrypt + gallery; macOS Swift capture implemented (runtime unverified here) |
| M5 | Dashboard & reports | **Advanced** | Compact premium dashboard, project/task flows, timeline, reports, activity sparkline |
| M5b | Admin testing + desktop UX | **Advanced** | Dev/prod AppEnv isolation, admin panel, settings sections, window bounds persistence |
| M5c | Firebase Google Auth + web admin | **Deferred** | Removed from active desktop path for now; local auth restored |
| M6 | Harden & build | Pending | Tray, crash recovery UX, broader hardening |

## Vertical slice note

Priority execution delivered a working path: **Login → Dashboard → native Start Tracking → pause/resume/stop → persisted sessions**, before secondary screens.

Update status when a milestone is verified — not when scaffolding starts.
