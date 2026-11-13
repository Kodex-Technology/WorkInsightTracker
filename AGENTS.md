# AGENTS.md — Witrack

Instructions for AI coding agents working in this repository.

## Product

- Display brand: **WorkInsight Tracker** (UI lockup: mark + WorkInsight / Tracker)
- Technical identifier: `witrack` / `com.witrack.desktop` (never rename package casually)
- Phase 1: Windows-first Flutter desktop tracker; macOS architecture-ready
- Tagline: Work smarter. Track clearly.
- Theme: dark Work Insights palette by default; light via existing `themeModeProvider`

## Single sources of truth

| Concern | Document |
|---|---|
| Requirements | [docs/product/requirements.md](docs/product/requirements.md) |
| Tracking policies | [docs/tracking/tracking-policies.md](docs/tracking/tracking-policies.md) |
| Architecture | [docs/architecture/system-architecture.md](docs/architecture/system-architecture.md) |
| Design tokens | [docs/design/design-system.md](docs/design/design-system.md) |
| Milestones | [docs/planning/milestones.md](docs/planning/milestones.md) |
| Acceptance | [docs/testing/acceptance-criteria.md](docs/testing/acceptance-criteria.md) |
| Decisions | [docs/planning/decisions.md](docs/planning/decisions.md) |

Docs index: [docs/README.md](docs/README.md)

## Non-negotiable rules

1. Implement real functionality; never present mocks as complete tracking.
2. No keystroke content, clipboard, passwords, or hidden monitoring.
3. Document new tracking defaults in `tracking-policies.md` before coding them.
4. Keep platform APIs behind the TrackingEngine interface (Pigeon).
5. Prefer minimum high-quality code — no speculative layers or unused packages.
6. Interfaces only at platform, auth, storage, and sync boundaries.
7. Risk-based tests: state machine, time math, idle, persistence, recovery — not trivia.
8. Do not claim tests/builds passed without running them.
9. Architecture changes require an entry in `docs/planning/decisions.md`.
10. Update milestone status in `docs/planning/milestones.md` when a milestone completes.
11. External backend / attendance / portal integrations must use provider adapters (see `docs/architecture/backend-api.md`) and must never call remote services from the native tracking engine.
12. Future Google/auth/API work must stay dynamic: no hardcoded roles/emails in UI; parse backend payloads via `ApiResult` / soft maps so unknown fields do not crash the app.

## Code layout

```
lib/
  app/           bootstrap, router, theme wiring
  core/          tokens, constants, shared utilities
  domain/        tracking orchestration (added when needed)
  data/          Drift + repositories (M2+)
  platform/      Pigeon facades (M3+)
  features/      splash, auth, shell, dashboard, …
windows/runner/tracking/   Windows C++ engine (M3+)
```

## Stack (locked)

Flutter Desktop · Riverpod · GoRouter · Drift/SQLite · Pigeon · secure storage  
Windows: C++ native engine · macOS: Swift later behind the same interface

## Milestone focus

Work the current milestone in [milestones.md](docs/planning/milestones.md). Do not skip ahead with fake UI data for unfinished native engines.
