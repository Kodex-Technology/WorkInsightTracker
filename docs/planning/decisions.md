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
