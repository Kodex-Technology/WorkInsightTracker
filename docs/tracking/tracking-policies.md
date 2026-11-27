# Tracking policies (source of truth)

Any new default must be added here **before** implementation.

## Locked defaults

| Policy | Value |
|---|---|
| Activity evaluation interval | **10 seconds** |
| Idle threshold | **5 minutes** without input |
| Idle behavior | Mark session **Idle**; do **not** auto-pause or auto-stop |
| Screenshot interval (default) | **10 minutes** |
| Screenshot interval options | **1, 5, 10, 15** minutes (admin/settings; min **1**) |
| Screenshot schedule | Fixed interval (extensible later for randomized) |
| Tracking section rollover | Close the current local session segment and open a new segment at every configured tracking interval, whether screenshots are enabled or not |
| Capture while | Authorized **Tracking** or **Idle** only |
| No capture while | **Paused** or **Stopped** |
| Input tracking | Non-content activity signals only |
| Activity signal source (Windows) | `GetLastInputInfo` idle age; **no fabricated key/mouse counts** |
| Activity sample fields | `secondsSinceLastInput`, `isActiveSignal` (idle age under 10s), `foregroundApp` |
| Screenshot productivity | **Active sample %** over the interval since previous capture (or session start): `activeSamples / totalSamples × 100` |
| Screenshot event detail | Interval summary only: input-activity pulses, app/focus switches, idle enters, session events — **no** key/mouse content, **no** fabricated click counters |
| Task productivity | Average of that task’s screenshot productivity scores for the filtered day (when screenshots exist) |
| Keystroke content | **Never** recorded |
| Window titles | **Not stored** in the current vertical slice (process name only) |
| Clipboard / passwords | **Never** collected |
| Application tracking | Foreground app + permitted window metadata |
| Storage | Screenshot image bytes are uploaded through the authenticated backend API to private S3 storage using S3 server-side AES-256 encryption; object keys are `tracker-screenshots/YYYY-MM-DD/{user_id}/{uuid}.png`. The desktop stores screenshot metadata locally only for tracking/productivity; image files are not retained locally for new captures. |
| Background | Continue while minimized to tray |
| Stop/pause | User-controlled only (plus explicit recovery flows) |
| Privacy | Disclosure, permissions, sensitive-app exclusions |
| Idle / screenshot notices | **Separate native toast windows** (not in-app overlays); bottom-right of work area; closable; auto-dismiss ~7s |
| Notice feature flags | Admin: `idleNotices`, `screenshotNotices` (default on); screenshot also respects Settings `notifyOnScreenshot` |

## Sensitive app exclusions

User-configurable exclusion list (process name / app id). While excluded app is foreground:

- Do not record window titles that may be sensitive (store app identity only or skip interval — exact behavior documented in [application-monitoring.md](application-monitoring.md) before coding)
- Screenshots skipped for that interval

## Time accounting

- **activeMs**: time in Tracking with system awake/unlocked
- **idleMs**: time in Idle state
- **pausedMs**: time in Paused
- Sleep and lock intervals are **excluded** from active work and recorded as session signals

## Project / task start rules

- **No default project or default task** is auto-created. Projects and tasks are now **optional**.
- Tracking segments can be started with or without a project and task.
- **Start Tracking** is enabled whenever tracking is stopped or in an error state, regardless of whether a project or task is selected.
- **Project click** → browse / select project only; **never** starts or switches the timer.
- **Task click** → always **ask** (“Are you sure you want to start/switch this task?”); on confirm, start if stopped or switch if live (current task segment ends; **Today (all work)** continues).
- **Mark completed / Delete** → if a timer is open, **ask**; on confirm, **stop first**, then mutate. Never auto-restart after that stop.
- Completed tasks move to a separate **Completed** list (feature-flagged); day/week/month progress still includes their locked time.
- **Tracking core** (timer / events / capture) is the master feature and cannot be turned off in admin toggles.

## Changing policies

Runtime updates via settings → native `updatePolicies` where safe; otherwise apply on next start. Document behavior per setting in settings UI copy.
