# Requirements (source of truth)

Phase 1 priority: **fully functional local Windows desktop tracking**.

## Functional

1. Premium splash and onboarding entry
2. Local development authentication with persistent session
3. Prepared Google OAuth (PKCE) architecture — not required for Phase 1 completion
4. Dashboard with real-time local metrics
5. Session controls: start, pause, resume, stop, recover
6. Keyboard/mouse **metadata** sampling (no typed content)
7. Idle detection per [tracking policies](../tracking/tracking-policies.md)
8. Foreground application / window metadata tracking
9. Automatic screenshots on fixed interval with multi-monitor support
10. Encrypted local screenshot storage
11. Activity timeline; daily and weekly reports
12. Tracking, screenshot, privacy, and local admin settings
13. Offline-first Drift/SQLite persistence
14. Crash / unexpected-shutdown recovery
15. Windows system tray integration with visible status
16. Permission, error, and recovery UX
17. Future sync outbox schema (no required backend in Phase 1)

## Non-functional

- Premium, consistent desktop UI (dark/light)
- Low background CPU/memory; no busy polling
- Secure credential and screenshot handling
- Cross-platform domain; Windows C++ / future macOS Swift natives
- Risk-based automated tests + Windows manual/integration checks
- High-DPI aware windowing

## Explicit non-goals (Phase 1)

- Production backend server
- Keylogging / clipboard capture
- Hidden tracking without user control
- Full Google OAuth production configuration (architecture only)
- Feature-complete macOS native engine

## Related

- Scope: [feature-scope.md](feature-scope.md)
- Acceptance: [../testing/acceptance-criteria.md](../testing/acceptance-criteria.md)
