# Testing strategy

Risk-based. Automate deterministic logic; validate OS behavior on Windows.

## Mandatory automation

- Session state machine
- Time calculation / aggregations
- Idle transition logic
- Activity aggregation
- Screenshot scheduling rules
- DB migrations & repository persistence
- Crash recovery decisions
- Auth session restore

## UI

Critical navigation and auth gates only — not hundreds of static widget tests.

## Native

Manual / integration on real Windows: start/stop, tray, foreground switch, idle, screenshots, sleep/wake, lock/unlock, restart recovery. Mocks alone do not verify the engine.

## Rules

- No weakened assertions to “make CI green”
- Never claim unexecuted tests passed
- Keep suites fast and maintainable
