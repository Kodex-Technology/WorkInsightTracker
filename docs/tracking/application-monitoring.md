# Application monitoring

## Captured fields

- Process name / executable
- Application display name when available
- Window title **only when permitted** and app not excluded
- Start/end timestamps for foreground intervals

## Behavior

- On foreground change, close previous `app_usage_intervals` row and open a new one
- Honor sensitive exclusions from settings
- No browser URL scraping in Phase 1 unless separately decided and documented

## Privacy

Window titles can contain secrets (email subjects, filenames). Prefer exclusions and clear user disclosure. Default: store titles; allow setting to disable titles.
