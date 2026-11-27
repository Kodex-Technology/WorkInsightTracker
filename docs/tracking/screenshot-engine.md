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

- Upload capture bytes through the authenticated Laravel API to private S3.
- S3 object key: `tracker-screenshots/YYYY-MM-DD/{user_id}/{uuid}.png`.
- Laravel requests S3 server-side AES-256 encryption; short-lived signed read URLs come from the listing API.
- Desktop keeps screenshot metadata for tracking/productivity, not new image files.

## Performance

Compress before encrypt; avoid capturing on UI thread; bound concurrent encodes.
