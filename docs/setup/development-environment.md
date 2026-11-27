# Development environment

## Required

1. Flutter stable (`flutter doctor`)
2. Windows: Visual Studio with **Desktop development with C++**
3. Git (recommended)

## Setup

```bash
cd /path/to/WItrack
cp .env.example .env
flutter pub get
flutter run -d windows
```

Set `API_BASE_URL` in `.env` to the Laravel API server. Production builds use `.env.production`; see [windows-build.md](windows-build.md).

On macOS, use `make run-mac` to pass `.env` to the sandboxed app. These values are embedded in the build, so do not put secrets in `.env`. Fully restart the app after changes; hot reload does not update build-time values.

## Analysis & tests

```bash
flutter analyze
flutter test
```

See [windows-build.md](windows-build.md).
