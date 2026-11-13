import 'package:witrack/data/database/app_database.dart';

class TrackingSettings {
  const TrackingSettings({
    this.screenshotEnabled = true,
    this.screenshotIntervalMinutes = 10,
    this.idleThresholdMinutes = 5,
    this.autoPauseOnIdle = false,
    this.excludeIdleFromActive = true,
    this.collectWindowTitles = false,
    this.minimizeToTray = true,
    this.notifyOnScreenshot = true,
    this.onboardingCompleted = false,
  });

  final bool screenshotEnabled;
  final int screenshotIntervalMinutes;
  final int idleThresholdMinutes;
  final bool autoPauseOnIdle;
  final bool excludeIdleFromActive;
  final bool collectWindowTitles;
  final bool minimizeToTray;
  final bool notifyOnScreenshot;
  final bool onboardingCompleted;

  TrackingSettings copyWith({
    bool? screenshotEnabled,
    int? screenshotIntervalMinutes,
    int? idleThresholdMinutes,
    bool? autoPauseOnIdle,
    bool? excludeIdleFromActive,
    bool? collectWindowTitles,
    bool? minimizeToTray,
    bool? notifyOnScreenshot,
    bool? onboardingCompleted,
  }) {
    return TrackingSettings(
      screenshotEnabled: screenshotEnabled ?? this.screenshotEnabled,
      screenshotIntervalMinutes:
          screenshotIntervalMinutes ?? this.screenshotIntervalMinutes,
      idleThresholdMinutes: idleThresholdMinutes ?? this.idleThresholdMinutes,
      autoPauseOnIdle: autoPauseOnIdle ?? this.autoPauseOnIdle,
      excludeIdleFromActive:
          excludeIdleFromActive ?? this.excludeIdleFromActive,
      collectWindowTitles: collectWindowTitles ?? this.collectWindowTitles,
      minimizeToTray: minimizeToTray ?? this.minimizeToTray,
      notifyOnScreenshot: notifyOnScreenshot ?? this.notifyOnScreenshot,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }
}

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Future<TrackingSettings> load() async {
    final rows = await _db.select(_db.appSettings).get();
    final map = {for (final r in rows) r.key: r.value};
    return TrackingSettings(
      screenshotEnabled: map['screenshotEnabled'] != 'false',
      screenshotIntervalMinutes:
          int.tryParse(map['screenshotIntervalMinutes'] ?? '') ?? 10,
      idleThresholdMinutes:
          int.tryParse(map['idleThresholdMinutes'] ?? '') ?? 5,
      autoPauseOnIdle: map['autoPauseOnIdle'] == 'true',
      excludeIdleFromActive: map['excludeIdleFromActive'] != 'false',
      collectWindowTitles: map['collectWindowTitles'] == 'true',
      minimizeToTray: map['minimizeToTray'] != 'false',
      notifyOnScreenshot: map['notifyOnScreenshot'] != 'false',
      onboardingCompleted: map['onboardingCompleted'] == 'true',
    );
  }

  Future<void> save(TrackingSettings settings) async {
    Future<void> put(String key, String value) async {
      await _db.into(_db.appSettings).insertOnConflictUpdate(
            AppSettingsCompanion.insert(key: key, value: value),
          );
    }

    await put('screenshotEnabled', settings.screenshotEnabled.toString());
    await put(
      'screenshotIntervalMinutes',
      settings.screenshotIntervalMinutes.toString(),
    );
    await put(
      'idleThresholdMinutes',
      settings.idleThresholdMinutes.toString(),
    );
    await put('autoPauseOnIdle', settings.autoPauseOnIdle.toString());
    await put(
      'excludeIdleFromActive',
      settings.excludeIdleFromActive.toString(),
    );
    await put('collectWindowTitles', settings.collectWindowTitles.toString());
    await put('minimizeToTray', settings.minimizeToTray.toString());
    await put('notifyOnScreenshot', settings.notifyOnScreenshot.toString());
    await put('onboardingCompleted', settings.onboardingCompleted.toString());
  }
}
