# Acceptance criteria (source of truth)

## Phase 1 complete

1. Windows app branded Witrack with premium dark/light UI
2. Local auth works end-to-end with persistence
3. Native engine tracks while UI minimized to tray
4. Start/pause/resume/stop + Idle behave per policies
5. Activity, app usage, screenshots are real and queryable
6. Dashboard/reports reflect DB — no placeholder datasets
7. Settings change tracking behavior where specified
8. Crash/restart recovers or cleanly closes interrupted session
9. Automated critical tests + successful `flutter build windows`
10. macOS project present; native stubbed; no core rewrite expected for Swift later

## M0

- Flutter project with windows + macos platforms
- Docs structure + AGENTS.md + README present
- Design tokens + dark/light themes
- Branded splash → app shell
- `flutter analyze` clean
- Essential tests pass
- Windows run/build verified when toolchain available

## Tracking vertical slice (current)

- Local development login + session restore
- Dashboard Start/Pause/Resume/Stop wired to Windows native engine
- Elapsed timer accrues; pause stops active accrual
- Foreground application updates from native process identity
- Idle after 5 minutes without input (no auto-pause)
- Activity samples persist `secondsSinceLastInput` / `isActiveSignal` (not fake counts)
- Completed sessions survive app restart
- Navigating shell routes does not reset an active tracking controller
- `flutter analyze` clean; essential tests pass; Windows release build succeeds

Manual Windows checks: see [manual-test-checklist.md](manual-test-checklist.md).
