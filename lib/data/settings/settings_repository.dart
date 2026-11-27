import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:witrack/core/config/app_env.dart';
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

  Future<void> saveRemote(
    TrackingSettings settings, {
    required String token,
  }) async {
    final response = await http.put(
      _settingsUri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'screenshot_enabled': settings.screenshotEnabled,
        'screenshot_interval_minutes': settings.screenshotIntervalMinutes,
        'idle_threshold_minutes': settings.idleThresholdMinutes,
        'auto_pause_on_idle': settings.autoPauseOnIdle,
        'exclude_idle_from_active': settings.excludeIdleFromActive,
        'collect_window_titles': settings.collectWindowTitles,
        'notify_on_screenshot': settings.notifyOnScreenshot,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Server rejected preferences (HTTP ${response.statusCode}): ${response.body}');
    }
  }

  Uri get _settingsUri {
    return AppEnv.apiUri('tracker/settings');
  }

  Future<TrackingSettings?> loadRemote({required String token}) async {
    final response = await http.get(
      _settingsUri,
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Could not load server preferences (HTTP ${response.statusCode}).');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['data'] is! Map) return null;
    final data = Map<String, dynamic>.from(decoded['data'] as Map);
    bool boolean(String key, bool fallback) {
      final value = data[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.toLowerCase();
        if (normalized == 'true' || normalized == '1') return true;
        if (normalized == 'false' || normalized == '0') return false;
      }
      return fallback;
    }
    int integer(String key, int fallback) => int.tryParse('${data[key]}') ?? fallback;
    return TrackingSettings(
      screenshotEnabled: boolean('screenshot_enabled', true),
      screenshotIntervalMinutes: integer('screenshot_interval_minutes', 10),
      idleThresholdMinutes: integer('idle_threshold_minutes', 5),
      autoPauseOnIdle: boolean('auto_pause_on_idle', false),
      excludeIdleFromActive: boolean('exclude_idle_from_active', true),
      collectWindowTitles: boolean('collect_window_titles', false),
      notifyOnScreenshot: boolean('notify_on_screenshot', true),
    );
  }

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
