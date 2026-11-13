# User flows

## First launch

1. Splash → Welcome
2. Local sign-in (dev account) or future Google path
3. Permissions / privacy disclosure
4. Main shell (Dashboard)

## Daily tracking

1. User presses **Start**
2. Status shows Tracking; tray reflects state
3. Activity samples and app usage accumulate locally
4. Screenshots captured on interval while Tracking/Idle (not Paused/Stopped)
5. Idle after threshold → state Idle (session continues)
6. User Pause / Resume / Stop as needed
7. Dashboard and reports update from local DB

## Minimize / tray

1. Close or minimize sends app to tray while tracking may continue
2. Tray menu: Show, Pause/Resume, Stop, Quit
3. Tracking status remains visible in tray tooltip/menu

## Recovery

1. Unexpected exit leaves recoverable session marker
2. Next launch offers recover or discard per [lifecycle-recovery.md](../tracking/lifecycle-recovery.md)

## Auth restore

1. Cold start loads secure session
2. Authenticated → shell; otherwise → login
