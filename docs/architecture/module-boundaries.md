# Module boundaries

## Allowed dependencies

```text
features → domain, data (via providers), core, platform facade
domain   → core only (no Flutter UI, no Drift, no dart:io platform APIs)
data     → domain types, Drift, secure storage, file IO
platform → pigeon generated code; wraps native
app      → wires everything
```

## Rules

1. One canonical tracking engine implementation per OS.
2. Do not put Win32/AppKit types in domain models.
3. Repositories are the only writers of tracking tables.
4. UI reads via Riverpod streams/providers — no Drift queries in `build()`.
5. Create interfaces only at: TrackingEngine, AuthProvider, secure storage, sync outbox.

## Feature folders

Each feature owns its screens and feature-local providers. Shared widgets live in `core` or a small `features/shared` only when reused by 2+ features.
