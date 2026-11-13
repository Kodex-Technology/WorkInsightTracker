# Known limitations

## Current

- System tray / macOS menu bar controls not finished
- Lock/sleep/wake accounting not finished
- Crash recovery UX prompt not finished
- Manual time entry not finished
- Admin policy UI is minimal (settings cover core policies)
- CSV/PDF export not finished
- Browser URL extension integration not finished
- Google OAuth not enabled end-to-end
- Custom app icon still default Flutter icon
- **macOS Swift tracking/screenshot code is in-repo but not runtime-verified on this Windows development host**

## Implemented recently

- Expanded Drift schema (projects/tasks/screenshots/app usage/settings/…)
- Project/task selection before Start Tracking
- Real Windows multi-monitor screenshot capture + AES encryption + gallery
- macOS native MethodChannel engine (idle via CGEventSource, apps via NSWorkspace, capture via CGWindowList)
- Timeline and basic reports from SQLite
- Settings that update idle threshold / screenshot interval / auto-pause flag
- Permissions onboarding screen

Track new limitations here when discovered; do not list unfinished milestones as bugs.
