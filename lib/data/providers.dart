import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:witrack/data/auth/auth_repository.dart';
import 'package:witrack/data/database/app_database.dart';
import 'package:witrack/data/projects/project_repository.dart';
import 'package:witrack/data/screenshots/screenshot_store.dart';
import 'package:witrack/data/settings/settings_repository.dart';
import 'package:witrack/data/tracking/session_repository.dart';
import 'package:witrack/platform/method_channel_tracking_engine.dart';
import 'package:witrack/platform/tracking_engine.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main()');
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(sharedPreferencesProvider),
  );
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(ref.watch(appDatabaseProvider));
});

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(ref.watch(appDatabaseProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(appDatabaseProvider));
});

final screenshotStoreProvider = Provider<ScreenshotStore>((ref) {
  return ScreenshotStore(ref.watch(appDatabaseProvider));
});

final trackingEngineProvider = Provider<TrackingEngine>((ref) {
  final engine = MethodChannelTrackingEngine();
  ref.onDispose(engine.dispose);
  return engine;
});
