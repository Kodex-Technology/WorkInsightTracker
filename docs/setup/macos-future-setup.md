# macOS setup

Flutter `macos/` ships a **Swift MethodChannel engine** (`WitrackTrackingPlugin.swift`) matching Windows methods: start/pause/resume/stop/poll/updatePolicies/captureDisplays/permissionStatus/showDesktopNotice.

## Honest status

**Not 100% feature-guaranteed** until runtime QA on a Mac. Full matrix: [weaknesses-and-readiness.md](../planning/weaknesses-and-readiness.md).

## Run

```bash
flutter run -d macos
```

Accept **Screen Recording** (screenshots) and grant **Accessibility** if prompted (input idle reliability).

## Later polish

1. ScreenCaptureKit instead of deprecated `CGWindowListCreateImage`  
2. `NSStatusItem` tray parity  
3. Lock/sleep signals (same gap as Windows)  
4. Production Google/OIDC when backend auth is live  

Do not fork Dart domain/UI for macOS — only the native adapter. Never call remote APIs from native tracking.
