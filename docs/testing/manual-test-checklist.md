# Manual test checklist (Windows)

Use after M3+ for native paths. Check boxes during verification runs.

## M0

- [ ] App launches to splash then shell
- [ ] Dark theme looks correct; light theme toggles if exposed
- [ ] Window resize retains usable layout
- [ ] Title / branding shows Witrack

## Tracking vertical slice

- [ ] Dev login → dashboard
- [ ] Start creates a session and timer advances
- [ ] Foreground app name updates when switching apps
- [ ] Idle after 5 minutes without input (session stays running)
- [ ] Pause stops active-time accrual; Resume continues
- [ ] Stop persists completed session
- [ ] Restart shows session in Recent sessions
- [ ] Navigate to Timeline and back; tracking state still live

## Tracking (remaining)

- [ ] Minimize to tray; tracking continues
- [ ] Lock/unlock and sleep/wake accounting
- [ ] Restart recovery prompt

## Screenshots (M4+)

- [ ] Capture on interval while tracking
- [ ] No capture while paused/stopped
- [ ] Multi-monitor files present
- [ ] Gallery opens encrypted captures
