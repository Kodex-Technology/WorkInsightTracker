# Screenshot engine

## Schedule

- Fixed interval: default **10 min**; options **5 / 10 / 15**
- Only while session is **Tracking** or **Idle**
- Never while **Paused** or **Stopped**
- Randomized scheduler is future extension only

## Capture

- All active displays (multi-monitor)
- Store one encrypted file per display capture (or multi-page package — decide at M4 and record in [decisions.md](../planning/decisions.md))
- Optional user notification on capture

## Storage

- App support directory `screenshots/`
- Encrypt at rest; DB holds path, hash, display id, takenAt, sessionId

## Performance

Compress before encrypt; avoid capturing on UI thread; bound concurrent encodes.
