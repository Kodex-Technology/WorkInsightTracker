# Activity and idle detection

## Activity signal model (implemented)

Windows idle age comes from **`GetLastInputInfo`**. That API provides time since last input — **not** discrete keyboard/mouse event counts.

Do **not** fabricate separate key/mouse counts. Productivity and screenshot
detail use **input-activity pulses** (`isActiveSignal == true` samples) and
**app/focus switches** already stored in Drift — never raw click streams.

Each 10-second evaluation persists:

| Field | Meaning |
|---|---|
| `secondsSinceLastInput` | Idle age from `GetLastInputInfo` at sample time |
| `isActiveSignal` | `true` when idle age is **&lt; 10 seconds** (input within the evaluation window) |
| `foregroundApp` | Foreground process display name (no window title) |

Native worker refreshes idle age and foreground process about once per second. Flutter polls snapshots and emits/persists activity samples every **10 seconds** while status is Tracking or Idle.

## Idle

- If no input for **5 minutes**, native status becomes **Idle**
- Session remains running; do **not** auto-pause or auto-stop
- On input resume → status **Tracking**

## Implementation notes (Windows)

- `GetLastInputInfo` for idle threshold and activity signal
- `GetForegroundWindow` + process image name for app identity
- No busy loops — 1s worker sleep + Dart poll
