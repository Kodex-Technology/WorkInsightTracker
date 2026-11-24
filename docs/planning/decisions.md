# Architecture decisions

## ADR-001 — Single Flutter app (defer packages)

**Decision:** Start as one Flutter application with layered folders; extract packages only if boundaries hurt after M3.  
**Why:** Avoid premature monorepo overhead.  
**Date:** 2026-11-11

## ADR-002 — Windows-first, shared engine interface

**Decision:** Ship Windows C++ engine first; keep Pigeon contract stable for future Swift.  
**Why:** Fastest path to a real tracker on the development OS.  
**Date:** 2026-11-11

## ADR-003 — Idle marks state, does not auto-pause

**Decision:** After 5 minutes idle, enter Idle; do not auto-pause/stop.  
**Why:** Product policy — user retains control.  
**Date:** 2026-11-11

## ADR-004 — Fixed screenshot intervals first

**Decision:** Fixed 5/10/15 minute intervals; randomized scheduler later.  
**Why:** Simpler correctness; extensible scheduler interface.  
**Date:** 2026-11-11

## ADR-005 — Local auth before Google OAuth

**Decision:** Fully functional local dev auth in Phase 1; Google PKCE prepared.  
**Why:** Unblocks tracking work without OAuth credentials.  
**Date:** 2026-11-11

## ADR-006 — Activity signal via GetLastInputInfo

**Decision:** Persist idle-age activity signals (`secondsSinceLastInput`, `isActiveSignal`). Do not fabricate keyboard/mouse event counts.  
**Why:** `GetLastInputInfo` cannot provide exact input counts; privacy-respecting and honest.  
**Date:** 2026-11-11

## ADR-007 — MethodChannel poll bridge for vertical slice

**Decision:** Use MethodChannel `poll` snapshots (1s) instead of EventChannel push for the first Windows engine.  
**Why:** Avoids cross-thread EventSink complexity while keeping a stable Dart `TrackingEngine` interface.  
**Date:** 2026-11-11

## ADR-008 — Vertical slice before secondary screens

**Decision:** Deliver auth + native tracking + dashboard controls + Drift persistence before tray/screenshots/full reports.  
**Why:** Fastest path to a real Start Tracking experience.  
**Date:** 2026-11-11

## ADR-009 — Firebase Auth IdP + PKCE system browser + web admin

**Decision (superseded for now):** Firebase Google Auth + web admin was prototyped, then **deferred**. Desktop ships with local development auth only until Google/Firebase is re-enabled deliberately.  
**Why:** Disk/SDK and setup friction blocked a reliable Windows Google auth path; product priority is working local tracking.  
**Date:** 2026-11-12

## ADR-010 — Remove Reports screen

**Decision:** Delete the Reports feature (route, nav, `FeatureId.reports`, `ENABLE_REPORTS`). Insights live on the dashboard Progress rings + activity sparkline.  
**Why:** Duplicate surface; dashboard already shows live Active/Idle/Paused mix.  
**Date:** 2026-11-13

## ADR-011 — Single backend-api.md + readiness doc

**Decision:** Replace split backend/gap/roadmap limitation docs with `docs/architecture/backend-api.md` (APIs/JSON) and `docs/planning/weaknesses-and-readiness.md`. macOS is architecture-ready, not claimed 100% until Mac QA.  
**Why:** Fewer duplicate MDs; clearer deploy contract.  
**Date:** 2026-11-13

## ADR-012 — Windows Single-Instance Deep Link Forwarding

**Decision:** Enforce single-instance execution on Windows using a named Mutex and `WM_COPYDATA` message forwarding. When a deep link (`witrack://...`) is opened while the app is running, the second instance forwards the URI to the running instance, brings the existing window to the foreground, navigates to authentication, and exits.
**Why:** Prevents multiple tracker window instances and ensures deep link tokens (auth flow) are seamlessly handled by the active running instance.
**Date:** 2026-11-13

## ADR-013 — Optional Project and Task for Tracking Start

**Decision:** Make project and task selection optional for starting tracking. Users can start the timer without a project or task, or select a project and task if desired.
**Why:** Increases flexibility for unstructured work while maintaining full project/task attribution when projects/tasks are used.
**Date:** 2026-11-13

