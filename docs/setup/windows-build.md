# Windows build

```bash
flutter pub get
flutter run -d windows
# Before a production build, set the deployed API URL in .env.production.
flutter build windows --dart-define=APP_ENV=production
```

Development reads `.env` from the project directory. Production builds read `.env.production` beside the executable; the Windows bundle step copies that file next to the app. `API_BASE_URL` may be an origin or include `/api`; endpoints are resolved consistently. `.env.production` is configured with the production API URL used by the web frontend.

To change servers after packaging, edit `.env.production` next to `witrack.exe` and restart the app.

## Firebase C++ SDK disk requirement

`firebase_core` on Windows downloads `firebase_cpp_sdk_windows_*.zip` (~900MB+) and extracts it under `build/windows/`. Plan for **several GB free** on the drive hosting the project (or set `FIREBASE_CPP_SDK_DIR` to a pre-extracted SDK path).

If CMake fails with `archive_write_finish_entry` / extract errors, free disk space, delete `build/`, and rebuild.

Optional:

```bat
set FIREBASE_CPP_SDK_DIR=C:\path\to\firebase_cpp_sdk_windows
flutter build windows --dart-define-from-file=config\dev.json
```
