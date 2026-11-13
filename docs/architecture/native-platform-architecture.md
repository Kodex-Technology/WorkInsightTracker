# Native platform architecture

## Contract

Typed Pigeon API (`TrackingEngineApi`) shared by Windows and macOS.

### Host APIs (Dart → native)

- `start`, `pause`, `resume`, `stop`, `recover`, `getStatus`
- `updatePolicies` (idle threshold, sample interval, screenshot interval, exclusions)
- tray registration helpers as needed

### Flutter APIs (native → Dart)

- `onActivitySample`
- `onForegroundAppChanged`
- `onIdleStateChanged`
- `onScreenshotCaptured`
- `onSessionSignal` (lock/unlock/sleep/wake)
- `onTrayCommand`

## Windows (Phase 1)

C++ under `windows/runner/tracking/`:

| Concern | Approach |
|---|---|
| Idle / last input | `GetLastInputInfo` |
| Activity counts | Low-level hooks or raw input metadata counters (no content) |
| Foreground app | `GetForegroundWindow` + process query |
| Screenshots | GDI / Windows Graphics Capture; multi-monitor enum |
| Session | `WTSRegisterSessionNotification`, power broadcast |
| Tray | `Shell_NotifyIcon` |

RAII for handles; no busy loops; timer/event driven sampling.

## macOS (future)

Swift + AppKit / ScreenCaptureKit / CGEventSourceSecondsSinceLastEventType / NSStatusItem. Same Pigeon contract; permissions for Screen Recording / Accessibility as required.

## Rule

Platform logic must not leak into Flutter domain models — only DTO events cross the boundary.
