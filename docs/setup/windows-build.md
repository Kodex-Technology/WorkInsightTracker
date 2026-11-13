# Windows build

```bash
flutter pub get
flutter run -d windows --dart-define-from-file=config/dev.json
# or
flutter build windows --dart-define-from-file=config/prod.json
```

Production posture: `APP_ENV=production` and `ENABLE_LOCAL_DEV_AUTH=false` in the define file.

## Firebase C++ SDK disk requirement

`firebase_core` on Windows downloads `firebase_cpp_sdk_windows_*.zip` (~900MB+) and extracts it under `build/windows/`. Plan for **several GB free** on the drive hosting the project (or set `FIREBASE_CPP_SDK_DIR` to a pre-extracted SDK path).

If CMake fails with `archive_write_finish_entry` / extract errors, free disk space, delete `build/`, and rebuild.

Optional:

```bat
set FIREBASE_CPP_SDK_DIR=C:\path\to\firebase_cpp_sdk_windows
flutter build windows --dart-define-from-file=config\dev.json
```
