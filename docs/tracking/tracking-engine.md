# Tracking engine

Orchestration lives in Flutter domain; OS sampling in native Windows C++.

## Implemented (vertical slice)

| Piece | Location |
|---|---|
| Native engine | `windows/runner/tracking/tracking_engine.cpp` |
| Method channel | `com.witrack.desktop/tracking` (`start`/`pause`/`resume`/`stop`/`getStatus`/`poll`) |
| Dart facade | `lib/platform/windows_tracking_engine.dart` |
| Domain clock | `lib/domain/tracking/session_clock.dart` |
| UI controller | `lib/features/tracking/tracking_controller.dart` |
| Persistence | Drift tables: sessions, events, activity_samples |

### Runtime flow

1. User starts tracking in Flutter.
2. Drift session row is created.
3. Native engine starts a 1s worker using `GetLastInputInfo` + foreground process lookup.
4. Dart polls `poll` every 1s, updates UI status/app, accrues time, and writes a sample every 10s.
5. Pause/resume/stop call native methods and persist state/durations.

### Activity model

See [activity-idle-detection.md](activity-idle-detection.md). Uses idle-age signals — **not** fabricated key/mouse counts.

## Responsibilities

**Domain**

- Session clock (active/idle/paused)
- Persist via repositories
- Expose state to UI (survives route changes via Riverpod)

**Native**

- Idle threshold (5 min) without auto-pause
- Foreground process identity (no window titles)
- Snapshot fields for Dart polling

## Not yet implemented

- System tray / menu bar controls
- Lock/sleep session signals
- Full crash recovery UX

## Screenshots

Shared Dart scheduler + encrypted store. Native `captureDisplays`:

- Windows: GDI+/BitBlt multi-monitor PNG
- macOS: CGWindowListCreateImage per NSScreen (requires Screen Recording)

## macOS note

Swift plugin is implemented in `macos/Runner/WitrackTrackingPlugin.swift`. Runtime verification requires a Mac.

## State machine

See [system-architecture.md](../architecture/system-architecture.md). Transitions persist as `session_events`.
