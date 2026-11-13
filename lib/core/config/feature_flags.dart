/// Compile-time feature flags for Witrack.
///
/// Override with `--dart-define=ENABLE_*=true|false`.
/// Defaults keep local tracking useful; backend sync stays off until adapters exist.
///
/// See docs/architecture/future-backend-integration.md and tracking-policies.md.
abstract final class FeatureFlags {
  /// Day / week / month calendar progress module.
  static const bool enableCalendar = bool.fromEnvironment(
    'ENABLE_CALENDAR',
    defaultValue: true,
  );

  /// Separate "Completed today" list on the dashboard tree.
  static const bool enableCompletedList = bool.fromEnvironment(
    'ENABLE_COMPLETED_LIST',
    defaultValue: true,
  );

  /// Screenshots gallery + capture pipeline.
  static const bool enableScreenshots = bool.fromEnvironment(
    'ENABLE_SCREENSHOTS',
    defaultValue: true,
  );

  /// Reports screen (activity insights).
  static const bool enableReports = bool.fromEnvironment(
    'ENABLE_REPORTS',
    defaultValue: true,
  );

  /// Timeline screen.
  static const bool enableTimeline = bool.fromEnvironment(
    'ENABLE_TIMELINE',
    defaultValue: true,
  );

  /// Projects management screen (create/list outside dashboard tree).
  static const bool enableProjectsScreen = bool.fromEnvironment(
    'ENABLE_PROJECTS_SCREEN',
    defaultValue: true,
  );

  /// Remote sync / portal adapters — off until a backend is chosen.
  static const bool enableBackendSync = bool.fromEnvironment(
    'ENABLE_BACKEND_SYNC',
    defaultValue: false,
  );

  /// Official attendance check-in (separate from Start Tracking).
  static const bool enableAttendance = bool.fromEnvironment(
    'ENABLE_ATTENDANCE',
    defaultValue: false,
  );

  /// Ask before stopping an open timer on complete/delete.
  static const bool confirmStopBeforeMutate = bool.fromEnvironment(
    'CONFIRM_STOP_BEFORE_MUTATE',
    defaultValue: true,
  );

  /// Ask before switching live task segment (day total continues).
  static const bool confirmTaskSwitch = bool.fromEnvironment(
    'CONFIRM_TASK_SWITCH',
    defaultValue: true,
  );

  static const bool enableIdleNotices = bool.fromEnvironment(
    'ENABLE_IDLE_NOTICES',
    defaultValue: true,
  );

  static const bool enableScreenshotNotices = bool.fromEnvironment(
    'ENABLE_SCREENSHOT_NOTICES',
    defaultValue: true,
  );
}
