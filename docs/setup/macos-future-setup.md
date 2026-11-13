# macOS future setup

Phase 1 includes `macos/` scaffolding. Google → Firebase auth uses the **same Dart PKCE loopback flow** as Windows (`http://127.0.0.1:<port>/callback`). No custom URL scheme is required for the primary callback.

## Auth verification checklist (runtime — pending until run on a Mac)

1. Fill `config/dev.json` with the macOS/web Firebase app ids as registered.
2. `flutter run -d macos --dart-define-from-file=config/dev.json`
3. Continue with Google → system browser → consent → loopback success page → app session.
4. Quit/relaunch → Firebase session restores; local Drift data still keyed by stable local user id.
5. Confirm Screen Recording / Accessibility prompts still work for tracking.

Mark macOS auth **passed** only after steps 3–5 succeed on Apple hardware. Windows-only development leaves this **pending**.

## Later native work

1. Xcode + CocoaPods as required by Flutter
2. Implement Swift TrackingEngine conforming to Pigeon API
3. Request Screen Recording / Accessibility permissions with UX copy
4. NSStatusItem parity with Windows tray

Do not fork domain or UI for macOS — only the native adapter. External backends must use provider adapters; never call remote services from the native tracking engine.
